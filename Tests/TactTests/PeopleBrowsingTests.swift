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

    func testToggleAlternatesBetweenGridAndList() {
        XCTAssertEqual(PeopleLayout.grid.toggled, .list)
        XCTAssertEqual(PeopleLayout.list.toggled, .grid)
        XCTAssertEqual(PeopleLayout.colors.toggled, .list, "a hidden layout counts as the grid")
    }

    func testToggledLayoutIsRemembered() {
        let defaults = TestSupport.defaults()
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid, "grid until chosen otherwise")

        PeopleLayout.remembered(in: defaults).toggled.remember(in: defaults)
        XCTAssertEqual(defaults.string(forKey: PeopleLayout.storageKey), "list", "stored as @AppStorage stores it")
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .list)

        PeopleLayout.remembered(in: defaults).toggled.remember(in: defaults)
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid)

        defaults.set("flashcards", forKey: PeopleLayout.storageKey)
        XCTAssertEqual(PeopleLayout.remembered(in: defaults), .grid, "a hidden layout falls back to the grid")
    }

    // MARK: Tabs

    func testNotesTabIsTheListModeOfPeople() {
        XCTAssertEqual(RootTab.notes.layout(remembered: .grid), .list)
        XCTAssertEqual(RootTab.notes.layout(remembered: .list), .list)
        XCTAssertEqual(RootTab.people.layout(remembered: .grid), .grid)
        XCTAssertEqual(RootTab.people.layout(remembered: .list), .list)
        XCTAssertEqual(RootTab.allCases, [.people, .notes], "two tabs, no Games or Search tab")
        XCTAssertEqual(RootTab.notes.title, "Notes")
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

    func testEditIconOnlyInListMode() {
        XCTAssertEqual(HeaderAction.actions(for: .grid, tab: .people), [.search, .layoutToggle, .add, .settings])
        XCTAssertEqual(HeaderAction.actions(for: .list, tab: .people), [.search, .layoutToggle, .add, .edit, .settings])
        XCTAssertFalse(HeaderAction.actions(for: .grid, tab: .people).contains(.edit))
        XCTAssertTrue(HeaderAction.actions(for: .list, tab: .people).contains(.edit))
        XCTAssertEqual(HeaderAction.actions(for: .grid, tab: .people).count, 4)
    }

    func testNotesTabHasNoLayoutToggle() {
        XCTAssertEqual(HeaderAction.actions(for: .list, tab: .notes), [.search, .add, .edit, .settings])
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

    // MARK: Games tile

    func testGamesTileSitsAfterEveryoneAndSurvivesTheSearch() {
        let all = PeopleGridItems(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(all.tiles.map(\.person.id), [ada.id, grace.id])
        XCTAssertEqual(all.gamesCell, 2, "the first cell after the last tile")

        let filtered = PeopleGridItems(people: store.people, notes: store.notes, query: "grace")
        XCTAssertEqual(filtered.tiles.map(\.person.id), [grace.id])
        XCTAssertEqual(filtered.tiles.map(\.cell), [1], "tiles keep their cells")
        XCTAssertEqual(filtered.gamesCell, 2, "the Games tile stays where it was")

        let none = PeopleGridItems(people: store.people, notes: store.notes, query: "nobody")
        XCTAssertEqual(none.tiles, [])
        XCTAssertEqual(none.gamesCell, 2)
        XCTAssertEqual(none.occupiedCells, [2], "the canvas still has the Games tile to size around")
    }

    func testGamesTileFollowsTheLowestTile() {
        store.moveTile(personID: grace.id, toCell: 9)
        let items = PeopleGridItems(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(items.gamesCell, 10)
        XCTAssertEqual(PeopleGridItems(people: [], notes: [], query: "").gamesCell, 0, "with no one, the Games tile is first")
    }
}
