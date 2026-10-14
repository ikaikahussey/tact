import XCTest
@testable import Tact

final class GridPuzzleTests: XCTestCase {
    func testBoardFillsTheRowsThatFit() {
        // 852pt / (98 + 1) → 8 full rows of 4, less the blank.
        XCTAssertEqual(PeopleGridContent.boardCount(height: 852, squareSize: 98, spacing: 1, columns: 4), 31)
        XCTAssertEqual(PeopleGridContent.boardCount(height: 98, squareSize: 97, spacing: 1, columns: 4), 3)
        XCTAssertEqual(PeopleGridContent.boardCount(height: 97, squareSize: 97, spacing: 1, columns: 4), 0)
        XCTAssertEqual(PeopleGridContent.boardCount(height: 556, squareSize: 97, spacing: 1, columns: 4), 19)
        XCTAssertEqual(PeopleGridContent.boardCount(height: 0, squareSize: 97, spacing: 1, columns: 4), 0)
        XCTAssertEqual(PeopleGridContent.boardCount(height: 500, squareSize: 0, spacing: 1, columns: 4), 0)
    }

    func testPuzzleUsesThePeopleInListOrder() {
        let people = (0..<10).map { Person(name: "P\($0)") }
        let puzzle = PeopleGridContent.makePuzzle(people: people, boardCount: 7, columns: 4)
        XCTAssertEqual(puzzle.solvedOrder, people.prefix(7).map(\.id))
        XCTAssertEqual(puzzle.slots.count, 8)
        XCTAssertEqual(puzzle.rows, 2)
        XCTAssertTrue(puzzle.isSolved)
        XCTAssertEqual(puzzle.blankIndex, 7)
    }

    func testShuffledBoardCanBeRestoredToGridOrder() {
        let people = (0..<11).map { Person(name: "P\($0)") }
        var puzzle = PeopleGridContent.makePuzzle(people: people, boardCount: 11, columns: 4)
        puzzle.shuffle()
        XCTAssertFalse(puzzle.isSolved)
        XCTAssertEqual(Set(puzzle.slots.compactMap { $0 }), Set(people.map(\.id)))
        let restored = SlidingPuzzle(tileIDs: puzzle.solvedOrder, columns: 4)
        XCTAssertEqual(restored.slots.compactMap { $0 }, people.map(\.id))
    }
}
