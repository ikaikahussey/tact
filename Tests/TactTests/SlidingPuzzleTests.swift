import XCTest
@testable import Tact

final class SlidingPuzzleTests: XCTestCase {
    private let ids = (0..<7).map { _ in UUID() }   // 7 tiles + blank = 2 rows of 4

    func testStartsSolvedWithBlankLast() {
        let puzzle = SlidingPuzzle(tileIDs: ids)
        XCTAssertTrue(puzzle.isSolved)
        XCTAssertEqual(puzzle.blankIndex, 7)
        XCTAssertEqual(puzzle.slots.count, 8)
    }

    func testTappingAdjacentTileSlidesItIntoBlank() {
        var puzzle = SlidingPuzzle(tileIDs: ids)
        XCTAssertTrue(puzzle.tap(6))
        XCTAssertEqual(puzzle.blankIndex, 6)
        XCTAssertEqual(puzzle.slots[7], ids[6])
        XCTAssertFalse(puzzle.isSolved)
        XCTAssertTrue(puzzle.tap(7))
        XCTAssertTrue(puzzle.isSolved)
    }

    func testTappingTileInBlankRowSlidesWholeRun() {
        var puzzle = SlidingPuzzle(tileIDs: ids)
        XCTAssertEqual(puzzle.run(from: 4), [4, 5, 6])
        XCTAssertTrue(puzzle.tap(4))
        XCTAssertEqual(puzzle.slots[4...7].map { $0 }, [nil, ids[4], ids[5], ids[6]])
    }

    func testTappingColumnSlidesVertically() {
        var puzzle = SlidingPuzzle(tileIDs: ids)
        XCTAssertTrue(puzzle.tap(3))   // directly above the blank
        XCTAssertEqual(puzzle.slots[7], ids[3])
        XCTAssertEqual(puzzle.blankIndex, 3)
    }

    func testTappingUnrelatedTileOrBlankDoesNothing() {
        var puzzle = SlidingPuzzle(tileIDs: ids)
        XCTAssertFalse(puzzle.tap(0))
        XCTAssertFalse(puzzle.tap(7))
        XCTAssertFalse(puzzle.tap(99))
        XCTAssertTrue(puzzle.isSolved)
    }

    func testShuffleKeepsEveryTileAndLeavesPuzzleUnsolved() {
        var puzzle = SlidingPuzzle(tileIDs: ids)
        var generator = SystemRandomNumberGenerator()
        puzzle.shuffle(moves: 200, using: &generator)
        XCTAssertEqual(Set(puzzle.slots.compactMap { $0 }), Set(ids))
        XCTAssertEqual(puzzle.slots.filter { $0 == nil }.count, 1)
        XCTAssertFalse(puzzle.isSolved)
    }

    func testSinglePersonPuzzle() {
        var puzzle = SlidingPuzzle(tileIDs: [ids[0]])
        XCTAssertTrue(puzzle.tap(0))
        XCTAssertEqual(puzzle.slots, [nil, ids[0]])
        puzzle.shuffle(moves: 10)
        XCTAssertEqual(puzzle.slots.compactMap { $0 }, [ids[0]])
    }
}
