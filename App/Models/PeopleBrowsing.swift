import Foundation

/// The icons on the right of the header, in order. The view itself is
/// picked by the people/notes/games switch on the left. Edit and Settings
/// live under More.
enum HeaderAction: CaseIterable {
    case search, add, more

    var systemImage: String {
        switch self {
        case .search: return "magnifyingglass"
        case .add:    return "plus"
        case .more:   return "ellipsis.circle"
        }
    }

    /// The icons the root offers, the same in every view. Searching over a
    /// game turns the tiles back so the results can be seen.
    static func actions(for layout: PeopleLayout) -> [HeaderAction] {
        allCases
    }

    /// What More offers: Edit and Listen where there are people to edit
    /// and hear, Select and Bring Together only over the grid, Turn Tiles
    /// Over while a game is on their back, Settings always.
    static func moreItems(for layout: PeopleLayout) -> [MoreItem] {
        switch layout.resolved {
        case .games: return [.turnOver, .settings]
        case .list:  return [.edit, .listen, .settings]
        default:     return [.edit, .select, .listen, .bringTogether, .settings]
        }
    }
}

/// The entries of the header's More menu. Listen is a mode, like Edit:
/// while it is on, tapping a person plays their ditty instead of opening
/// them, so the earcons can be heard and compared without leaving the
/// grid or list. Select is a mode too: tapping tiles gathers them, and a
/// bar below changes all of them at once. Bring Together closes the gaps
/// between tiles. Turn Tiles Over ends a game, turning the tiles face up.
enum MoreItem: CaseIterable {
    case edit, select, listen, bringTogether, turnOver, settings
}

extension PeopleLayout {
    /// The name of the view: the list of people with their notes is the
    /// Notes view.
    var viewTitle: String {
        switch resolved {
        case .list:  return "Notes"
        case .games: return "Games"
        default:     return "People"
        }
    }

    /// The icon on the header's switch.
    var switchImage: String {
        switch resolved {
        case .list:  return "note.text"
        case .games: return "puzzlepiece.fill"
        default:     return "person.2.fill"
        }
    }

    /// Reads the remembered layout the way `@AppStorage` stores it.
    static func remembered(in defaults: UserDefaults) -> PeopleLayout {
        defaults.string(forKey: storageKey).flatMap(PeopleLayout.init(rawValue:))?.resolved ?? standard
    }

    func remember(in defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

/// Filters people and notes by the header search field. A person matches
/// when their name (or linked contact's name) or any of their notes contains
/// the query. A query starting with `#` is a tag search: a note matches
/// only when it carries exactly that tag, a person when they carry it
/// themself or one of their notes does, and names are not searched.
enum PeopleSearch {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether `note` is a hit for the (normalized, non-empty) query.
    static func noteMatches(_ note: Note, query: String) -> Bool {
        if let tag = NoteTags.queryTag(query) { return note.hasTag(tag) }
        if NoteTags.isTagQuery(query) { return false }
        return note.text.localizedCaseInsensitiveContains(query)
    }

    static func nameMatches(_ person: Person, query: String) -> Bool {
        person.name.localizedCaseInsensitiveContains(query)
            || (person.contact?.name.localizedCaseInsensitiveContains(query) ?? false)
    }

    /// Whether the person themself is a hit for the (normalized, non-empty)
    /// query, before their notes are looked at: their name for a plain
    /// query, their own tags for a tag query.
    static func personMatches(_ person: Person, query: String) -> Bool {
        if let tag = NoteTags.queryTag(query) { return person.hasTag(tag) }
        if NoteTags.isTagQuery(query) { return false }
        return nameMatches(person, query: query)
    }

    /// People shown in the grid for `query`; everyone when it is empty.
    static func people(_ people: [Person], notes: [Note], query rawQuery: String) -> [Person] {
        let query = normalized(rawQuery)
        guard !query.isEmpty else { return people }
        return people.filter { person in
            personMatches(person, query: query)
                || notes.contains { $0.isLinked(to: person.id) && noteMatches($0, query: query) }
        }
    }

    /// One section per person for the list: their notes newest first. With a
    /// query, people who match themselves (by name, or by their own tags)
    /// keep all their notes; otherwise only the matching notes are shown,
    /// and people with none are left out.
    static func sections(people: [Person], notes: [Note], query rawQuery: String) -> [PersonSection] {
        let query = normalized(rawQuery)
        return people.compactMap { person in
            let own = notes.filter { $0.isLinked(to: person.id) }.sorted { $0.date > $1.date }
            if query.isEmpty || personMatches(person, query: query) {
                return PersonSection(person: person, notes: own)
            }
            let matching = own.filter { noteMatches($0, query: query) }
            return matching.isEmpty ? nil : PersonSection(person: person, notes: matching)
        }
    }
}

extension PeopleSearch {
    /// The notes alone for the list's Recent grouping, newest first, in
    /// sections by how long ago they are dated. With a query, a note stays
    /// when it matches itself or when someone it is about does (by name,
    /// or by their own tags). Buckets with no notes are left out.
    static func recentSections(people: [Person], notes: [Note], query rawQuery: String,
                               now: Date = Date(), calendar: Calendar = .current) -> [RecentSection] {
        let query = normalized(rawQuery)
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shown = notes.filter { note in
            guard !query.isEmpty else { return true }
            if noteMatches(note, query: query) { return true }
            return note.personIds.contains { id in byID[id].map { personMatches($0, query: query) } ?? false }
        }
        .sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: shown) { RecentBucket($0.date, now: now, calendar: calendar) }
        return RecentBucket.allCases.compactMap { bucket in
            grouped[bucket].map { RecentSection(bucket: bucket, notes: $0) }
        }
    }
}

struct PersonSection: Identifiable, Equatable {
    let person: Person
    let notes: [Note]
    var id: UUID { person.id }
}

/// What the grid draws: the tiles that match the search, each at its cell.
/// A stack is one tile, showing its first people and carrying everyone in
/// it; it is shown when anyone in it matches. A plain stack goes by its top
/// person's id, a tag stack by its own.
struct PeopleGridItems: Equatable {
    struct Tile: Equatable {
        /// The tile's id on the canvas: the person's, or a tag stack's.
        let id: UUID
        let cell: Int
        /// The person, or the first person of a stack.
        let person: Person
        /// Everyone in the stack, top first; empty for a tile on its own.
        var stack: [Person] = []
        /// The stack's id, when the tile is one.
        var stackID: UUID?
        /// The tag everyone in the stack carries, for a tag stack.
        var tag: String?
        /// The design chosen for the stack, if one was.
        var design: StackDesign?

        var isStack: Bool { stackID != nil && !stack.isEmpty }
        var isTagStack: Bool { tag != nil }
        /// The people the tile stands for.
        var ids: [UUID] { isStack ? stack.map(\.id) : [person.id] }
    }

    let tiles: [Tile]

    init(people: [Person], notes: [Note], query: String, tagStacks: [TagStack] = []) {
        let layout = TileLayout.cells(for: people, tagStacks: tagStacks)
        let shown = Set(PeopleSearch.people(people, notes: notes, query: query).map(\.id))
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let stacks = TileLayout.stacks(for: people)
        let records = Dictionary(tagStacks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        tiles = layout.compactMap { cell, id -> Tile? in
            if let record = records[id] {
                let members: [Person] = people.filter { record.holds($0) }
                guard let first = members.first, members.contains(where: { shown.contains($0.id) }) else { return nil }
                return Tile(id: id, cell: cell, person: first, stack: members, stackID: id, tag: record.tag,
                            design: record.design)
            }
            guard let person = byID[id] else { return nil }
            let memberIDs: [UUID] = person.tile.stack.flatMap { stacks[$0] } ?? []
            let members: [Person] = memberIDs.compactMap { byID[$0] }
            guard shown.contains(id) || memberIDs.contains(where: { shown.contains($0) }) else { return nil }
            return Tile(id: id, cell: cell, person: person, stack: members,
                        stackID: members.isEmpty ? nil : person.tile.stack,
                        design: members.isEmpty ? nil : person.tile.stackDesign)
        }
        .sorted { $0.cell < $1.cell }
    }

    /// Everyone the shown tiles stand for, in cell order, each once: what
    /// Select All gathers.
    var selectableIDs: [UUID] {
        var seen = Set<UUID>()
        return tiles.flatMap { $0.ids }.filter { seen.insert($0).inserted }
    }

    /// Every cell something sits in, for sizing the canvas.
    var occupiedCells: [Int] { tiles.map(\.cell) }
}
