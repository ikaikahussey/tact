import XCTest
@testable import Tact

final class LightsOutTests: XCTestCase {
    func testStartsSolvedAndEmpty() {
        let board = LightsOut(columns: 4, rows: 4)
        XCTAssertEqual(board.count, 16)
        XCTAssertTrue(board.isSolved)
        XCTAssertEqual(board.litCount, 0)
        XCTAssertEqual(board.moveCount, 0)
    }

    func testPressTogglesCellAndOrthogonalNeighbours() {
        var board = LightsOut(columns: 4, rows: 4)
        XCTAssertEqual(Set(board.affected(by: 5)), [5, 4, 6, 1, 9])
        XCTAssertTrue(board.press(5))
        XCTAssertEqual(board.litCount, 5)
        for cell in [5, 4, 6, 1, 9] { XCTAssertTrue(board.isLit(cell)) }
        XCTAssertFalse(board.isLit(0))
        XCTAssertEqual(board.moveCount, 1)
    }

    func testCornerAndEdgePressesStayOnTheBoard() {
        let board = LightsOut(columns: 4, rows: 4)
        XCTAssertEqual(Set(board.affected(by: 0)), [0, 1, 4])
        XCTAssertEqual(Set(board.affected(by: 15)), [15, 14, 11])
        XCTAssertEqual(Set(board.affected(by: 3)), [3, 2, 7])
        XCTAssertEqual(Set(board.affected(by: 12)), [12, 13, 8])
    }

    func testPressingTwiceUndoes() {
        var board = LightsOut()
        board.press(6)
        board.press(6)
        XCTAssertTrue(board.isSolved)
        XCTAssertEqual(board.moveCount, 2)
    }

    func testPressOffTheBoardDoesNothing() {
        var board = LightsOut()
        XCTAssertFalse(board.press(-1))
        XCTAssertFalse(board.press(16))
        XCTAssertEqual(board.moveCount, 0)
        XCTAssertEqual(board.affected(by: 99), [])
    }

    func testScrambleIsNeverSolvedAndResetsMoves() {
        var generator = SeededGenerator(seed: 7)
        for presses in [1, 3, 5, 8, 16, 40] {
            var board = LightsOut()
            board.scramble(presses: presses, using: &generator)
            XCTAssertFalse(board.isSolved, "presses \(presses)")
            XCTAssertEqual(board.moveCount, 0)
        }
    }

    func testScrambleIsSolvableByPressingTheSameCellsAgain() {
        // Replay the scramble's choices on a second board and press them back.
        var generator = SeededGenerator(seed: 42)
        var board = LightsOut()
        board.scramble(presses: 6, using: &generator)
        var pressed: [Int] = []
        var probe = LightsOut()
        var replay = SeededGenerator(seed: 42)
        var chosen = Set<Int>()
        while chosen.count < 6 { chosen.insert(Int.random(in: 0..<16, using: &replay)) }
        for cell in chosen { probe.press(cell); pressed.append(cell) }
        if probe.isSolved { let extra = Int.random(in: 0..<16, using: &replay); probe.press(extra); pressed.append(extra) }
        XCTAssertEqual(probe.lit, board.lit)
        for cell in pressed { board.press(cell) }
        XCTAssertTrue(board.isSolved)
    }

    func testSingleRowBoardHasNoVerticalNeighbours() {
        let board = LightsOut(columns: 4, rows: 1)
        XCTAssertEqual(Set(board.affected(by: 1)), [0, 1, 2])
    }
}
