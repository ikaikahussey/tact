import Foundation
import Combine

/// Single source of truth for people, notes and settings. All mutations go
/// through its methods so every change is validated and persisted.
///
/// Saves are debounced and written on a background queue; `flush` forces a
/// synchronous write (used when the app moves to the background).
final class TactStore: ObservableObject {
    @Published private(set) var people: [Person] {
        didSet { if people != oldValue { markDirty(.people) } }
    }
    @Published private(set) var notes: [Note] {
        didSet { if notes != oldValue { markDirty(.notes) } }
    }
    @Published var settings: GameTypeSettings {
        didSet { if settings != oldValue { markDirty(.settings) } }
    }

    private enum Target { case people, notes, settings }

    private let persistence: PersistenceController
    private let saveQueue = DispatchQueue(label: "app.tact.store.save", qos: .utility)
    private let saveDelay: TimeInterval
    private var dirty: Set<Target> = []
    private var pendingSave: DispatchWorkItem?

    init(
        persistence: PersistenceController = PersistenceController(),
        defaults: UserDefaults = .standard,
        saveDelay: TimeInterval = 0.5
    ) {
        self.persistence = persistence
        self.saveDelay = saveDelay
        let data = persistence.load(migratingFrom: defaults)
        people = data.people
        notes = data.notes
        settings = data.settings
        Self.migrateLayoutPreference(in: defaults)
    }

    // MARK: Lookup

    func person(id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    /// Notes linked to a person, newest first.
    func notes(for personID: UUID) -> [Note] {
        notes.filter { $0.isLinked(to: personID) }.sorted { $0.date > $1.date }
    }

    func noteCount(for personID: UUID) -> Int {
        notes.reduce(0) { $0 + ($1.isLinked(to: personID) ? 1 : 0) }
    }

    /// All notes, newest first.
    var sortedNotes: [Note] {
        notes.sorted { $0.date > $1.date }
    }

    func names(forPersonIDs ids: [UUID]) -> [String] {
        ids.compactMap { id in person(id: id)?.name }
    }

    // MARK: People

    @discardableResult
    func addPerson(named rawName: String) -> Person? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let person = Person(name: name)
        people.append(person)
        return person
    }

    func renamePerson(id: UUID, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = people.firstIndex(where: { $0.id == id }) else { return }
        people[index].name = name
    }

    func updatePhoto(forPersonID id: UUID, data: Data?) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        people[index].photoData = data
    }

    /// Removes a person. Notes linked only to that person are deleted; notes
    /// shared with other people are kept and simply unlinked.
    func deletePerson(id: UUID) {
        guard people.contains(where: { $0.id == id }) else { return }
        var remaining: [Note] = []
        for var note in notes {
            if note.personIds == [id] { continue }
            note.personIds.removeAll { $0 == id }
            remaining.append(note)
        }
        notes = remaining
        people.removeAll { $0.id == id }
    }

    func movePeople(fromOffsets source: IndexSet, toOffset destination: Int) {
        people.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Tiles

    func updateTile(forPersonID id: UUID, _ change: (inout TileArt) -> Void) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        change(&people[index].tile)
    }

    /// Moves a person's tile to a cell on the canvas, swapping with whoever
    /// is there. Everyone's current cell is pinned first so that filling the
    /// old spot doesn't shuffle unplaced tiles around.
    func moveTile(personID id: UUID, toCell target: Int) {
        guard target >= 0 else { return }
        let cellOf = Dictionary(uniqueKeysWithValues: TileLayout.cells(for: people).map { ($1, $0) })
        guard let source = cellOf[id], source != target else { return }
        var updated = people
        for index in updated.indices {
            let cell = cellOf[updated[index].id]
            updated[index].tile.cell = cell
            if updated[index].id == id {
                updated[index].tile.cell = target
            } else if cell == target {
                updated[index].tile.cell = source
            }
        }
        people = updated
    }

    func linkContact(toPersonID id: UUID, identifier: String, snapshot: ContactSnapshot) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        people[index].contactIdentifier = identifier
        people[index].contact = snapshot
    }

    func updateContact(forPersonID id: UUID, snapshot: ContactSnapshot) {
        guard let index = people.firstIndex(where: { $0.id == id }), people[index].hasLinkedContact else { return }
        people[index].contact = snapshot
    }

    func unlinkContact(fromPersonID id: UUID) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        people[index].contactIdentifier = nil
        people[index].contact = nil
    }

    // MARK: Notes

    @discardableResult
    func addNote(text rawText: String, personIds: [UUID] = []) -> Note? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let note = Note(personIds: orderedPersonIds(personIds), text: text)
        notes.append(note)
        return note
    }

    /// Updates text and links. `modifiedDate` moves only when something changed.
    func updateNote(id: UUID, text: String, personIds: some Collection<UUID>, now: Date = Date()) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let ordered = orderedPersonIds(personIds)
        guard notes[index].text != text || notes[index].personIds != ordered else { return }
        var note = notes[index]
        note.text = text
        note.personIds = ordered
        note.modifiedDate = now
        notes[index] = note
    }

    /// Changes when the note happened; this is the date notes are sorted by.
    func setNoteDate(id: UUID, to date: Date) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].date != date else { return }
        notes[index].date = date
    }

    /// A short title for a note: the first linked person, or the date.
    func title(for note: Note) -> String {
        names(forPersonIDs: note.personIds).first ?? note.date.formatted(date: .abbreviated, time: .omitted)
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func linkNote(id noteID: UUID, toPersonID personID: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }),
              !notes[index].personIds.contains(personID) else { return }
        notes[index].personIds = orderedPersonIds(notes[index].personIds + [personID])
    }

    func unlinkNote(id noteID: UUID, fromPersonID personID: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].personIds.removeAll { $0 == personID }
    }

    /// Orders person ids to match the People list, dropping duplicates.
    /// Ids that no longer match a person are kept (at the end) rather than lost.
    func orderedPersonIds(_ ids: some Collection<UUID>) -> [UUID] {
        var position: [UUID: Int] = [:]
        for (index, person) in people.enumerated() { position[person.id] = index }
        var seen = Set<UUID>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.sorted { (position[$0] ?? .max) < (position[$1] ?? .max) }
    }

    // MARK: Export

    func outline(now: Date = Date()) -> String {
        OutlineExporter.outline(people: people, notes: notes, now: now)
    }

    // MARK: Persistence

    private func markDirty(_ target: Target) {
        dirty.insert(target)
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    /// Writes any unsaved changes. Pass `waitUntilDone: true` to block until the
    /// files are on disk, for example when the app is about to be suspended.
    func flush(waitUntilDone: Bool = false) {
        pendingSave?.cancel()
        pendingSave = nil
        guard !dirty.isEmpty else {
            if waitUntilDone { saveQueue.sync {} }
            return
        }
        let targets = dirty
        dirty = []
        let people = self.people
        let notes = self.notes
        let settings = self.settings
        let persistence = self.persistence

        let work = {
            do {
                if targets.contains(.people) { try persistence.savePeople(people) }
                if targets.contains(.notes) { try persistence.saveNotes(notes) }
                if targets.contains(.settings) { try persistence.saveSettings(settings) }
            } catch {
                assertionFailure("Save failed: \(error)")
            }
        }
        if waitUntilDone {
            saveQueue.sync(execute: work)
        } else {
            saveQueue.async(execute: work)
        }
    }

    /// Version 1.0 stored the layout as two separate keys.
    static func migrateLayoutPreference(in defaults: UserDefaults) {
        guard defaults.object(forKey: PeopleLayout.storageKey) == nil else { return }
        let isListMode = defaults.object(forKey: "isListMode") as? Bool
        let gameType = defaults.string(forKey: "selectedGameType")
        guard isListMode != nil || gameType != nil else { return }

        let layout: PeopleLayout
        if isListMode ?? true {
            layout = .list
        } else {
            switch gameType {
            case "randomColor": layout = .colors
            case "flashcard":   layout = .flashcards
            case "art":         layout = .art
            default:            layout = .grid
            }
        }
        defaults.set(layout.rawValue, forKey: PeopleLayout.storageKey)
        defaults.removeObject(forKey: "isListMode")
        defaults.removeObject(forKey: "selectedGameType")
    }
}
