import Foundation
import Combine
import os

/// Where the iCloud backup stands, for display in Settings.
enum CloudBackupStatus: Equatable {
    /// Looking for iCloud and for a backup from an earlier install.
    case checking
    case on
    /// Not signed in to iCloud, or iCloud is turned off for Tact.
    case unavailable
    /// A backup exists but could not be downloaded; retried on next launch.
    case failed
}

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
    @Published private(set) var backupStatus: CloudBackupStatus

    /// Set once this install has merged in (or found no) earlier backup.
    static let backupMergedKey = "cloudBackupMerged"

    private enum Target { case people, notes, settings }

    private let persistence: PersistenceController
    private let saveQueue = DispatchQueue(label: "app.tact.store.save", qos: .utility)
    private let saveDelay: TimeInterval
    private var dirty: Set<Target> = []
    private var pendingSave: DispatchWorkItem?
    private let backupQueue = DispatchQueue(label: "app.tact.store.backup", qos: .utility)
    /// Only touched on `saveQueue`; `nil` until the backup is connected.
    private var backup: CloudBackup?
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tact", category: "Store")

    /// - Parameter makeBackup: Returns the iCloud backup, or `nil` when iCloud is
    ///   unavailable. Called once, off the main thread. Pass `nil` to keep data
    ///   on this device only.
    init(
        persistence: PersistenceController = PersistenceController(),
        defaults: UserDefaults = .standard,
        saveDelay: TimeInterval = 0.5,
        backup makeBackup: (() -> CloudBackup?)? = nil
    ) {
        self.persistence = persistence
        self.saveDelay = saveDelay
        let data = persistence.load(migratingFrom: defaults)
        people = data.people
        notes = data.notes
        settings = data.settings
        backupStatus = makeBackup == nil ? .unavailable : .checking
        Self.migrateLayoutPreference(in: defaults)
        if let makeBackup { connectBackup(makeBackup, defaults: defaults) }
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
    /// is there.
    func moveTile(personID id: UUID, toCell target: Int) {
        guard target >= 0 else { return }
        let anchors = TileLayout.anchors(for: people)
        guard let source = anchors[id], source != target else { return }
        people = Self.pinningTile(people, moving: id, to: target, anchors: anchors, vacated: source)
    }

    /// Closes the gaps on the Tiles canvas, keeping everyone's order.
    func bringTilesTogether() {
        let cells = TileLayout.compacted(people)
        var updated = people
        for index in updated.indices {
            updated[index].tile.cell = cells[updated[index].id]
        }
        people = updated
    }

    private static func pinningTile(_ people: [Person], moving id: UUID, to anchor: Int,
                                    anchors: [UUID: Int], vacated: Int?) -> [Person] {
        GridPlacement.pinning(people, moving: id, to: anchor, anchors: anchors, vacated: vacated,
                              cell: \.tile.cell, footprint: TileLayout.footprint(of:at:))
    }

    // MARK: Tangram

    /// Changes a person's Tangram piece. If the piece now overlaps others,
    /// they are pushed aside; the changed piece stays where it is.
    func updateTangram(forPersonID id: UUID, _ change: (inout TangramPiece) -> Void) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        var updated = Self.placingAll(people)
        change(&updated[index].tangram)
        people = Self.settled(updated, fixing: id)
    }

    /// Puts a person's piece with its centre at `centre` (in canvas cells),
    /// pushing aside whatever is in the way. Called repeatedly while a piece
    /// is dragged, so the others move out of its path.
    func moveTangram(personID id: UUID, to centre: TangramPiece.Point) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        var updated = Self.placingAll(people)
        updated[index].tangram.position = TangramLayout.clamped(centre, for: updated[index].tangram)
        people = Self.settled(updated, fixing: id)
    }

    /// Puts every listed piece at the centre given, as when a drag ends and
    /// the pieces it pushed aside come to rest.
    func setTangramPositions(_ centres: [UUID: TangramPiece.Point]) {
        var updated = people
        for index in updated.indices {
            if let centre = centres[updated[index].id] { updated[index].tangram.position = centre }
        }
        guard updated != people else { return }
        people = updated
    }

    /// Replaces several people's pieces at once, as when fitting everything
    /// together.
    func setTangramPieces(_ pieces: [UUID: TangramPiece]) {
        var updated = people
        for index in updated.indices {
            if let piece = pieces[updated[index].id] { updated[index].tangram = piece }
        }
        people = updated
    }

    /// Everyone with the position the canvas currently shows them at.
    private static func placingAll(_ people: [Person]) -> [Person] {
        let positions = TangramLayout.positions(for: people)
        var updated = people
        for index in updated.indices {
            updated[index].tangram.position = positions[updated[index].id]
        }
        return updated
    }

    /// Pushes overlapping pieces apart, leaving `fixed` where it is.
    private static func settled(_ people: [Person], fixing fixed: UUID) -> [Person] {
        var centres: [UUID: TangramPiece.Point] = [:]
        var pieces: [UUID: TangramPiece] = [:]
        for person in people {
            pieces[person.id] = person.tangram
            centres[person.id] = person.tangram.position ?? TangramLayout.clamped(.init(x: 0, y: 0), for: person.tangram)
        }
        TangramLayout.settle(&centres, pieces: pieces, fixed: fixed)
        var updated = people
        for index in updated.indices {
            updated[index].tangram.position = centres[updated[index].id]
        }
        return updated
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

    // MARK: Puzzle

    /// The user's chosen puzzle photo, or the Tact tiles.
    var puzzleImageData: Data {
        settings.artSettings.imageData ?? TactTilesImage.data
    }

    /// The picture for a puzzle: a person's photo when it is theirs and they
    /// have one, otherwise the standard picture.
    func puzzleImageData(for source: PuzzleImageSource) -> Data {
        switch source {
        case .standard:        return puzzleImageData
        case .person(let id):  return person(id: id)?.photoData ?? puzzleImageData
        }
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

        let work = { [weak self] in
            do {
                if targets.contains(.people) { try persistence.savePeople(people) }
                if targets.contains(.notes) { try persistence.saveNotes(notes) }
                if targets.contains(.settings) { try persistence.saveSettings(settings) }
            } catch {
                assertionFailure("Save failed: \(error)")
            }
            self?.mirrorToBackup()
        }
        if waitUntilDone {
            saveQueue.sync(execute: work)
        } else {
            saveQueue.async(execute: work)
        }
    }

    // MARK: iCloud backup

    /// Finds the iCloud backup. The first time this install sees one, its people
    /// and notes are merged in; after that every save is mirrored to it.
    private func connectBackup(_ makeBackup: @escaping () -> CloudBackup?, defaults: UserDefaults) {
        let alreadyMerged = defaults.bool(forKey: Self.backupMergedKey)
        backupQueue.async { [weak self] in
            guard let backup = makeBackup() else {
                DispatchQueue.main.async { self?.backupStatus = .unavailable }
                return
            }
            var restored: PersistedData?
            if !alreadyMerged && backup.hasBackup() {
                let staging = FileManager.default.temporaryDirectory
                    .appendingPathComponent("TactRestore-\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: staging) }
                do {
                    try backup.restore(into: staging)
                    restored = PersistenceController(directory: staging).load()
                } catch {
                    // Leave the backup untouched so this install cannot overwrite it.
                    self?.log.error("Restore failed: \(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async { self?.backupStatus = .failed }
                    return
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if let restored {
                    self.merge(restored)
                    // Queue the merged save ahead of the first mirror.
                    self.flush()
                }
                defaults.set(true, forKey: Self.backupMergedKey)
                self.backupStatus = .on
                self.saveQueue.async { [weak self] in
                    self?.backup = backup
                    self?.mirrorToBackup()
                }
            }
        }
    }

    /// Adds people and notes from an earlier backup that this install does not
    /// have. Anything created here before the backup arrived is kept.
    private func merge(_ restored: PersistedData) {
        let personIDs = Set(people.map(\.id))
        let noteIDs = Set(notes.map(\.id))
        people = restored.people.filter { !personIDs.contains($0.id) } + people
        notes += restored.notes.filter { !noteIDs.contains($0.id) }
        if settings == GameTypeSettings() { settings = restored.settings }
    }

    /// Copies the saved files to iCloud. Runs on `saveQueue`.
    private func mirrorToBackup() {
        guard let backup else { return }
        do {
            try backup.mirror(from: persistence.directory)
        } catch {
            log.error("Backup failed: \(error.localizedDescription, privacy: .public)")
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
