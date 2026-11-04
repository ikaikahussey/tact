import XCTest
@testable import Tact

final class EdgeSwipeTests: XCTestCase {
    private let width: CGFloat = 390

    private func target(_ layout: PeopleLayout, startX: CGFloat, dx: CGFloat, dy: CGFloat = 0,
                        predictedDX: CGFloat? = nil) -> PeopleLayout? {
        EdgeSwipe.target(from: layout, startX: startX,
                         translation: CGSize(width: dx, height: dy),
                         predictedTranslation: CGSize(width: predictedDX ?? dx, height: dy),
                         width: width)
    }

    func testRightEdgeSwipeLeftFromTilesShowsList() {
        XCTAssertEqual(target(.grid, startX: width - 5, dx: -120), .list)
    }

    func testRightEdgeSwipeLeftFromGamesShowsList() {
        XCTAssertEqual(target(.games, startX: width - 5, dx: -120), .list)
    }

    func testLeftEdgeSwipeRightFromListShowsTiles() {
        XCTAssertEqual(target(.list, startX: 4, dx: 120), .grid)
    }

    func testSwipeNotFromEdgeDoesNothing() {
        XCTAssertNil(target(.grid, startX: width / 2, dx: -120))
        XCTAssertNil(target(.list, startX: width / 2, dx: 120))
    }

    func testWrongDirectionDoesNothing() {
        XCTAssertNil(target(.grid, startX: width - 5, dx: 120))
        XCTAssertNil(target(.list, startX: 4, dx: -120))
    }

    func testWrongEdgeDoesNothing() {
        XCTAssertNil(target(.grid, startX: 4, dx: 120))
        XCTAssertNil(target(.list, startX: width - 5, dx: -120))
    }

    func testMostlyVerticalDragDoesNothing() {
        XCTAssertNil(target(.list, startX: 4, dx: 80, dy: 200))
    }

    func testShortSlowDragDoesNothing() {
        XCTAssertNil(target(.grid, startX: width - 5, dx: -30))
    }

    func testShortFlickSwitches() {
        XCTAssertEqual(target(.grid, startX: width - 5, dx: -30, predictedDX: -200), .list)
    }

    func testFlickBackCancels() {
        XCTAssertNil(target(.grid, startX: width - 5, dx: -100, predictedDX: 40))
    }

    func testBeginsOnlyAtTheRelevantEdge() {
        XCTAssertTrue(EdgeSwipe.begins(in: .grid, startX: width - 10, width: width))
        XCTAssertFalse(EdgeSwipe.begins(in: .grid, startX: 10, width: width))
        XCTAssertTrue(EdgeSwipe.begins(in: .list, startX: 10, width: width))
        XCTAssertFalse(EdgeSwipe.begins(in: .list, startX: width - 10, width: width))
    }

    func testZeroWidthDoesNothing() {
        XCTAssertNil(EdgeSwipe.target(from: .grid, startX: 0, translation: CGSize(width: -120, height: 0),
                                      predictedTranslation: CGSize(width: -120, height: 0), width: 0))
    }
}
