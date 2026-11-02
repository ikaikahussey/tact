import XCTest
@testable import Tact

/// The note's person picker: who comes first, how a query narrows the list,
/// and when typing a name offers to add someone new.
final class PersonPickerOrderTests: XCTestCase {
    private let ada = Person(name: "Ada Lovelace")
    private let grace = Person(name: "Grace Hopper")
    private let alan = Person(name: "Alan Turing")
    private let kat = Person(name: "Katherine Johnson")

    private func note(_ ids: [UUID], at seconds: TimeInterval) -> Note {
        Note(personIds: ids, text: "x", date: Date(timeIntervalSince1970: seconds))
    }

    func testEmptyQueryPutsMostRecentlyWrittenAboutFirstThenByName() {
        let notes = [note([ada.id], at: 1_000), note([grace.id], at: 3_000), note([ada.id, alan.id], at: 2_000)]
        let order = PersonPickerOrder.people([kat, ada, alan, grace], notes: notes, query: "")
        XCTAssertEqual(order.map(\.name), ["Grace Hopper", "Ada Lovelace", "Alan Turing", "Katherine Johnson"])
    }

    func testPeopleWithoutNotesSortByName() {
        let order = PersonPickerOrder.people([kat, grace, alan, ada], notes: [], query: "  ")
        XCTAssertEqual(order.map(\.name), ["Ada Lovelace", "Alan Turing", "Grace Hopper", "Katherine Johnson"])
    }

    func testQueryRanksNameStartThenWordStartThenContains() {
        let hopkins = Person(name: "Hope Hopkins")
        let chopra = Person(name: "Deepak Chopra")
        let order = PersonPickerOrder.people([chopra, grace, hopkins], notes: [], query: "hop")
        XCTAssertEqual(order.map(\.name), ["Hope Hopkins", "Grace Hopper", "Deepak Chopra"])
    }

    func testQueryIgnoresCaseAndAccentsAndDropsNonMatches() {
        let leilani = Person(name: "Leʻilani Kalā")
        let order = PersonPickerOrder.people([ada, leilani, grace], notes: [], query: "KALA")
        XCTAssertEqual(order.map(\.id), [leilani.id])
    }

    func testRecencyBreaksTiesWithinAMatchGroup() {
        let notes = [note([alan.id], at: 5_000)]
        let order = PersonPickerOrder.people([ada, alan], notes: notes, query: "a")
        XCTAssertEqual(order.map(\.name), ["Alan Turing", "Ada Lovelace"])
    }

    func testNewNameOfferedOnlyForAnUnusedName() {
        let people = [ada, grace]
        XCTAssertNil(PersonPickerOrder.newName(for: "", among: people))
        XCTAssertNil(PersonPickerOrder.newName(for: "   ", among: people))
        XCTAssertNil(PersonPickerOrder.newName(for: "ada lovelace", among: people))
        XCTAssertEqual(PersonPickerOrder.newName(for: "  Ada ", among: people), "Ada")
    }

    func testMatchRank() {
        XCTAssertEqual(PersonPickerOrder.matchRank(name: "Grace Hopper", query: ""), 0)
        XCTAssertEqual(PersonPickerOrder.matchRank(name: "Grace Hopper", query: "gr"), 0)
        XCTAssertEqual(PersonPickerOrder.matchRank(name: "Grace Hopper", query: "hop"), 1)
        XCTAssertEqual(PersonPickerOrder.matchRank(name: "Mary-Jane Watson", query: "jan"), 1)
        XCTAssertEqual(PersonPickerOrder.matchRank(name: "Grace Hopper", query: "ppe"), 2)
        XCTAssertNil(PersonPickerOrder.matchRank(name: "Grace Hopper", query: "xyz"))
    }
}
