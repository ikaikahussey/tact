import XCTest
@testable import Tact

final class EdgeSwipeTests: XCTestCase {
    private let width: CGFloat = 400

    private func target(_ layout: PeopleLayout, dx: CGFloat, dy: CGFloat = 0,
                        predictedDX: CGFloat? = nil) -> PeopleLayout? {
        EdgeSwipe.target(from: layout,
                         translation: CGSize(width: dx, height: dy),
                         predictedTranslation: CGSize(width: predictedDX ?? dx, height: dy),
                         width: width)
    }

    // MARK: Side

    func testSides() {
        XCTAssertEqual(EdgeSwipe.side(for: .grid), .trailing)
        XCTAssertEqual(EdgeSwipe.side(for: .games), .trailing)
        XCTAssertEqual(EdgeSwipe.side(for: .list), .leading)
        XCTAssertEqual(EdgeSwipe.side(for: .colors), .trailing, "hidden layouts resolve to tiles")
    }

    // MARK: Progress follows the finger

    func testProgressFromTilesFollowsLeftwardDrag() {
        XCTAssertEqual(EdgeSwipe.progress(from: .grid, translationX: 0, width: width), 0)
        XCTAssertEqual(EdgeSwipe.progress(from: .grid, translationX: -100, width: width), 0.25)
        XCTAssertEqual(EdgeSwipe.progress(from: .grid, translationX: -400, width: width), 1)
    }

    func testProgressFromTilesClampsAndIgnoresWrongWay() {
        XCTAssertEqual(EdgeSwipe.progress(from: .grid, translationX: -900, width: width), 1)
        XCTAssertEqual(EdgeSwipe.progress(from: .grid, translationX: 80, width: width), 0)
    }

    func testProgressFromListFollowsRightwardDrag() {
        XCTAssertEqual(EdgeSwipe.progress(from: .list, translationX: 0, width: width), 1)
        XCTAssertEqual(EdgeSwipe.progress(from: .list, translationX: 100, width: width), 0.75)
        XCTAssertEqual(EdgeSwipe.progress(from: .list, translationX: 900, width: width), 0)
        XCTAssertEqual(EdgeSwipe.progress(from: .list, translationX: -50, width: width), 1)
    }

    func testProgressWithZeroWidth() {
        XCTAssertNil(EdgeSwipe.progress(from: .grid, translationX: -50, width: 0))
    }

    // MARK: Lifting the finger

    func testFarEnoughFromTilesShowsList() {
        XCTAssertEqual(target(.grid, dx: -130), .list)
        XCTAssertEqual(target(.games, dx: -130), .list)
    }

    func testFarEnoughFromListShowsTiles() {
        XCTAssertEqual(target(.list, dx: 130), .grid)
    }

    func testShortSlowDragSettlesBack() {
        XCTAssertNil(target(.grid, dx: -60))
        XCTAssertNil(target(.list, dx: 60))
    }

    func testShortFlickSwitches() {
        XCTAssertEqual(target(.grid, dx: -40, predictedDX: -220), .list)
        XCTAssertEqual(target(.list, dx: 40, predictedDX: 220), .grid)
    }

    func testFlickBackCancels() {
        XCTAssertNil(target(.grid, dx: -250, predictedDX: 30))
        XCTAssertNil(target(.list, dx: 250, predictedDX: -30))
    }

    func testWrongDirectionDoesNothing() {
        XCTAssertNil(target(.grid, dx: 200))
        XCTAssertNil(target(.list, dx: -200))
    }

    func testMostlyVerticalDoesNothing() {
        XCTAssertNil(target(.grid, dx: -150, dy: 300))
    }

    func testZeroWidthDoesNothing() {
        XCTAssertNil(EdgeSwipe.target(from: .grid, translation: CGSize(width: -200, height: 0),
                                      predictedTranslation: CGSize(width: -200, height: 0), width: 0))
    }
}
