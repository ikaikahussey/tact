import XCTest
@testable import Tact

/// The navigation and header rules: the two tabs over one data source, the
/// remembered grid/list mode, the header's icons, and the search filter.
final class PeopleBrowsingTests: XCTestCase {
    private var store: TactStore!
    private var ada: Person!
    private var grace: Person!
    private var oldNote: Note!
    private var newNote: Note!
    private var graceNote: Note!

    override func setUp() {
        super.setUp()
        store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        ada = store.addPerson(named: "Ada Lovelace")
        grace = store.addPerson(named: "Grace Hopper")
        oldNote = store.addNote(text: "Met at the engine demo", personIds: [ada.id])
        store.setNoteDate(id: oldNote.id, to: Date(timeIntervalSince1970: 1_000))
        newNote = store.addNote(text: "Likes strong coffee", personIds: [ada.id])
        store.setNoteDate(id: newNote.id, to: Date(timeIntervalSince1970: 2_000))
        graceNote = store.addNote(text: "Wrote the compiler", personIds: [grace.id])
        store.setNoteDate(id: graceNote.id, to: Date(timeIntervalSince1970: 1_500))
    }

    // MARK: Grid / list toggle

    func testTheSwitchOffersPeopleNotesAndGames() {
        XCTAssertEqual(PeopleLayout.available, [.grid, .list, .games])
        XCTAssertEqual(PeopleLayout.games.resolved, .games)
        XCTAssertEqual(PeopleLayout.games.viewTitle, "Games")
        XCTAssertEqual(PeopleLayout.games.switchImage, "puzzlepiece.fill")
    }

    func testChosenViewIsRemembered() {
        let defaults = TestSupport.defaults()
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid, "grid until chosen otherwise")

        PeopleLayout.list.remember(in: defaults)
        XCTAssertEqual(defaults.string(forKey: PeopleLayout.storageKey), "list", "stored as @AppStorage stores it")
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .list)

        PeopleLayout.games.remember(in: defaults)
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .games)

        PeopleLayout.grid.remember(in: defaults)
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid)

        defaults.set("flashcards", forKey: PeopleLayout.storageKey)
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid, "a hidden layout falls back to the grid")
    }

    // MARK: View names

    func testListModeIsTheNotesView() {
        XCTAssertEqual(PeopleLayout.grid.viewTitle, "People")
        XCTAssertEqual(PeopleLayout.list.viewTitle, "Notes")
        XCTAssertEqual(PeopleLayout.flashcards.viewTitle, "People", "hidden layouts show as the grid")
        XCTAssertEqual(PeopleLayout.grid.switchImage, "person.2.fill")
        XCTAssertEqual(PeopleLayout.list.switchImage, "note.text")
    }

    // MARK: Sections

    func testSectionsListNotesNewestFirstUnderEachPerson() {
        let sections = PeopleSearch.sections(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(sections.map(\.person.id), [ada.id, grace.id], "people order")
        XCTAssertEqual(sections[0].notes.map(\.id), [newNote.id, oldNote.id], "newest first")
        XCTAssertEqual(sections[0].notes.count, 2, "the header's count")
        XCTAssertEqual(sections[1].notes.map(\.id), [graceNote.id])
    }

    func testPeopleWithoutNotesStillGetASection() {
        let newcomer = store.addPerson(named: "Alan")!
        let sections = PeopleSearch.sections(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(sections.last?.person.id, newcomer.id)
        XCTAssertEqual(sections.last?.notes, [])
    }

    // MARK: Header icons

    func testHeaderIconsAndMoreMenuByView() {
        XCTAssertEqual(HeaderAction.actions(for: .grid), [.search, .add, .more])
        XCTAssertEqual(HeaderAction.actions(for: .list), [.search, .add, .more])
        XCTAssertEqual(HeaderAction.actions(for: .games), [.add, .more], "nothing to search in the games")
        XCTAssertEqual(HeaderAction.moreItems(for: .grid), [.edit, .settings])
        XCTAssertEqual(HeaderAction.moreItems(for: .list), [.edit, .settings])
        XCTAssertEqual(HeaderAction.moreItems(for: .games), [.settings], "nothing to edit in the games")
    }

    // MARK: Search

    func testSearchFiltersTheGridByNameAndNoteText() {
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "grace").map(\.id), [grace.id])
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "COFFEE").map(\.id), [ada.id], "note text, any case")
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "nobody"), [])
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "  ").map(\.id), [ada.id, grace.id], "clearing restores everyone")
    }

    func testSearchFiltersTheListSectionsAndTheirNotes() {
        let byNote = PeopleSearch.sections(people: store.people, notes: store.notes, query: "coffee")
        XCTAssertEqual(byNote.map(\.person.id), [ada.id])
        XCTAssertEqual(byNote[0].notes.map(\.id), [newNote.id], "only the matching note")

        let byName = PeopleSearch.sections(people: store.people, notes: store.notes, query: "ada")
        XCTAssertEqual(byName.map(\.person.id), [ada.id])
        XCTAssertEqual(byName[0].notes.map(\.id), [newNote.id, oldNote.id], "a name match keeps every note, newest first")

        XCTAssertEqual(PeopleSearch.sections(people: store.people, notes: store.notes, query: "zzz"), [])
        XCTAssertEqual(PeopleSearch.sections(people: store.people, notes: store.notes, query: "").count, 2)
    }

    func testSearchMatchesTheLinkedContactName() {
        store.linkContact(toPersonID: ada.id, identifier: "c1",
                          snapshot: ContactSnapshot(name: "Augusta King"))
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "augusta").map(\.id), [ada.id])
    }

    // MARK: Grid

    func testGridKeepsCellsWhileSearching() {
        let all = PeopleGridItems(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(all.tiles.map(\.person.id), [ada.id, grace.id])
        XCTAssertEqual(all.occupiedCells, [0, 1])

        let filtered = PeopleGridItems(people: store.people, notes: store.notes, query: "grace")
        XCTAssertEqual(filtered.tiles.map(\.person.id), [grace.id])
        XCTAssertEqual(filtered.tiles.map(\.cell), [1], "tiles keep their cells")

        let none = PeopleGridItems(people: store.people, notes: store.notes, query: "nobody")
        XCTAssertEqual(none.tiles, [])
        XCTAssertEqual(none.occupiedCells, [])
    }
}
