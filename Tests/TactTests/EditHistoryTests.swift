import XCTest
@testable import Tact

final class EditHistoryTests: XCTestCase {
    func testStartsEmpty() {
        let history = EditHistory<Int>()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        var copy = history
        XCTAssertNil(copy.undo(current: 1))
        XCTAssertNil(copy.redo(current: 1))
    }

    func testUndoReturnsTheStateBeforeTheEdit() {
        var history = EditHistory<Int>()
        history.record(1)       // about to become 2
        XCTAssertTrue(history.canUndo)
        XCTAssertEqual(history.undo(current: 2), 1)
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
    }

    func testRedoRestoresWhatWasUndone() {
        var history = EditHistory<Int>()
        history.record(1)
        history.record(2)
        XCTAssertEqual(history.undo(current: 3), 2)
        XCTAssertEqual(history.undo(current: 2), 1)
        XCTAssertFalse(history.canUndo)
        XCTAssertEqual(history.redo(current: 1), 2)
        XCTAssertEqual(history.redo(current: 2), 3)
        XCTAssertFalse(history.canRedo)
        XCTAssertTrue(history.canUndo)
    }

    func testANewEditForgetsTheRedoFuture() {
        var history = EditHistory<Int>()
        history.record(1)
        _ = history.undo(current: 2)
        XCTAssertTrue(history.canRedo)
        history.record(1)       // a new edit from 1
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.undo(current: 9), 1)
    }

    func testRecordingTheSameStateTwiceKeepsItOnce() {
        var history = EditHistory<Int>()
        history.record(1)
        history.record(1)
        XCTAssertEqual(history.undoStack, [1])
    }

    func testTheLimitDropsTheOldestSteps() {
        var history = EditHistory<Int>(limit: 3)
        for value in 1...5 { history.record(value) }
        XCTAssertEqual(history.undoStack, [3, 4, 5])
        XCTAssertEqual(EditHistory<Int>(limit: 0).limit, 1)
    }

    func testClearForgetsEverything() {
        var history = EditHistory<Int>()
        history.record(1)
        _ = history.undo(current: 2)
        history.record(5)
        history.clear()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testWorksWithFatBits() {
        var history = EditHistory<FatBits>()
        var bits = FatBits.cross
        history.record(bits)
        bits[0, 0] = 3
        XCTAssertEqual(history.undo(current: bits), .cross)
        XCTAssertEqual(history.redo(current: .cross), bits)
    }
}
