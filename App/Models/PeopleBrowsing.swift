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

    /// The icons the root offers: everything for people and notes, no
    /// search over the games.
    static func actions(for layout: PeopleLayout) -> [HeaderAction] {
        allCases.filter { $0 != .search || layout.resolved != .games }
    }

    /// What More offers: Edit only where there is something to edit.
    static func moreItems(for layout: PeopleLayout) -> [MoreItem] {
        layout.resolved == .games ? [.settings] : [.edit, .settings]
    }
}

/// The entries of the header's More menu.
enum MoreItem: CaseIterable {
    case edit, settings
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
/// the query.
enum PeopleSearch {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func nameMatches(_ person: Person, query: String) -> Bool {
        person.name.localizedCaseInsensitiveContains(query)
            || (person.contact?.name.localizedCaseInsensitiveContains(query) ?? false)
    }

    /// People shown in the grid for `query`; everyone when it is empty.
    static func people(_ people: [Person], notes: [Note], query rawQuery: String) -> [Person] {
        let query = normalized(rawQuery)
        guard !query.isEmpty else { return people }
        return people.filter { person in
            nameMatches(person, query: query)
                || notes.contains { $0.isLinked(to: person.id) && $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    /// One section per person for the list: their notes newest first. With a
    /// query, people whose name matches keep all their notes; otherwise only
    /// the matching notes are shown, and people with none are left out.
    static func sections(people: [Person], notes: [Note], query rawQuery: String) -> [PersonSection] {
        let query = normalized(rawQuery)
        return people.compactMap { person in
            let own = notes.filter { $0.isLinked(to: person.id) }.sorted { $0.date > $1.date }
            if query.isEmpty || nameMatches(person, query: query) {
                return PersonSection(person: person, notes: own)
            }
            let matching = own.filter { $0.text.localizedCaseInsensitiveContains(query) }
            return matching.isEmpty ? nil : PersonSection(person: person, notes: matching)
        }
    }
}

struct PersonSection: Identifiable, Equatable {
    let person: Person
    let notes: [Note]
    var id: UUID { person.id }
}

/// What the grid draws: the tiles that match the search, each at its cell.
struct PeopleGridItems: Equatable {
    struct Tile: Equatable {
        let cell: Int
        let person: Person
    }

    let tiles: [Tile]

    init(people: [Person], notes: [Note], query: String) {
        let layout = TileLayout.cells(for: people)
        let shown = Set(PeopleSearch.people(people, notes: notes, query: query).map(\.id))
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        tiles = layout.compactMap { cell, id in
            guard shown.contains(id), let person = byID[id] else { return nil }
            return Tile(cell: cell, person: person)
        }
        .sorted { $0.cell < $1.cell }
    }

    /// Every cell something sits in, for sizing the canvas.
    var occupiedCells: [Int] { tiles.map(\.cell) }
}
