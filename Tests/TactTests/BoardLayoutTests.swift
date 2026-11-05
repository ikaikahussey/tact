import XCTest
import CoreGraphics
@testable import Tact

/// The board on one screen and across the iPhone Duo's fold.
final class BoardLayoutTests: XCTestCase {
    /// The Duo's inner display open in landscape, below the header: two
    /// halves either side of a fold.
    private let duo = CGSize(width: 951, height: 560)
    private let fold: ClosedRange<CGFloat> = 473...478

    private var spread: BoardLayout {
        BoardLayout.make(size: duo, fold: fold)
    }

    // MARK: One screen

    func testSingleBoardDrawsRowsStraightDown() {
        for width: CGFloat in [375, 402, 440, 669] {
            let layout = BoardLayout.make(size: CGSize(width: width, height: 800), fold: nil)
            XCTAssertFalse(layout.isSpread)
            let side = TileLayout.cellSide(forWidth: width)
            let inset = TileLayout.inset(forWidth: width, cellSide: side)
            XCTAssertEqual(layout.cellSide, side)
            for cell in [0, 3, 4, 9, 27] {
                XCTAssertEqual(layout.origin(of: cell),
                               CGPoint(x: inset + CGFloat(cell % 4) * (side + 1), y: CGFloat(cell / 4) * (side + 1)),
                               "\(width) cell \(cell)")
            }
            XCTAssertEqual(layout.drawnRows(forRows: 7), 7)
            XCTAssertEqual(layout.filledRows(atLeast: 7), 7)
        }
    }

    func testZoomShrinksTheSingleBoard() {
        let full = BoardLayout.single(width: 402)
        let half = BoardLayout.single(width: 402, zoom: 0.5)
        XCTAssertEqual(half.cellSide, (full.cellSide * 0.5).rounded(.down))
        XCTAssertGreaterThan(half.pageX[0], full.pageX[0], "the smaller board is centred")
    }

    // MARK: Across the fold

    func testFoldMakesTwoPagesEitherSide() {
        let layout = spread
        XCTAssertTrue(layout.isSpread)
        XCTAssertEqual(layout.pageCount, 2)
        XCTAssertLessThanOrEqual(layout.cellSide, TileLayout.maxCellSide)
        XCTAssertLessThanOrEqual(layout.pageX[0] + layout.boardWidth, fold.lowerBound, "left page stays left of the fold")
        XCTAssertGreaterThanOrEqual(layout.pageX[1], fold.upperBound, "right page starts past the fold")
        XCTAssertLessThanOrEqual(layout.pageX[1] + layout.boardWidth, duo.width)
    }

    func testTilesFlowFromTheLeftPageToTheRightPageThenBelow() throws {
        let layout = spread
        let perPage = try XCTUnwrap(layout.rowsPerPage)
        let perSpread = perPage * 2
        // First page.
        XCTAssertEqual(layout.slot(of: 0).page, 0)
        XCTAssertEqual(layout.slot(of: perPage * 4 - 1).page, 0)
        XCTAssertEqual(layout.slot(of: perPage * 4 - 1).row, perPage - 1)
        // The next row continues at the top of the right page.
        let firstRight = layout.slot(of: perPage * 4)
        XCTAssertEqual(firstRight.page, 1)
        XCTAssertEqual(firstRight.row, 0)
        XCTAssertEqual(firstRight.column, 0)
        // After both pages, the next spread starts on the left, below.
        let nextSpread = layout.slot(of: perSpread * 4 + 2)
        XCTAssertEqual(nextSpread.page, 0)
        XCTAssertEqual(nextSpread.row, perPage)
        XCTAssertEqual(nextSpread.column, 2)
    }

    func testSpreadPagesHoldAtLeastTheFourGameRows() throws {
        let short = BoardLayout.make(size: CGSize(width: 951, height: 200), fold: fold)
        XCTAssertTrue(short.isSpread)
        XCTAssertEqual(short.rowsPerPage, BoardLayout.minimumPageRows)
        // The sliding puzzle's 16 cells all sit on the first page.
        for cell in 0..<16 { XCTAssertEqual(short.slot(of: cell).page, 0, "\(cell)") }
    }

    func testEveryCellIsFoundAgainAtItsCentre() {
        for layout in [spread, BoardLayout.single(width: 402), BoardLayout.single(width: 669, zoom: 0.75)] {
            for cell in 0..<80 {
                XCTAssertEqual(layout.cell(at: layout.center(of: cell)), cell, "cell \(cell)")
            }
            XCTAssertNil(layout.cell(at: CGPoint(x: 10, y: -1)))
        }
    }

    func testNoCellInTheFoldOrMargins() {
        let layout = spread
        XCTAssertNil(layout.cell(at: CGPoint(x: (fold.lowerBound + fold.upperBound) / 2, y: 20)))
        XCTAssertNil(layout.cell(at: CGPoint(x: duo.width - 0.5, y: 20)))
    }

    func testCellsNeverOverlap() {
        let layout = spread
        var seen = Set<String>()
        for cell in 0..<96 {
            let o = layout.origin(of: cell)
            XCTAssertTrue(seen.insert("\(o.x),\(o.y)").inserted, "cell \(cell) drawn on another")
        }
    }

    func testRowsAndHeightOnASpread() throws {
        let layout = spread
        let perPage = try XCTUnwrap(layout.rowsPerPage)
        XCTAssertEqual(layout.drawnRows(forRows: 0), 0)
        XCTAssertEqual(layout.drawnRows(forRows: 2), 2)
        XCTAssertEqual(layout.drawnRows(forRows: perPage + 1), perPage, "the extra row is on the right page")
        XCTAssertEqual(layout.drawnRows(forRows: perPage * 2), perPage)
        XCTAssertEqual(layout.drawnRows(forRows: perPage * 2 + 1), perPage + 1)
        XCTAssertEqual(layout.height(rows: perPage * 2), CGFloat(perPage) * layout.pitch)
        XCTAssertEqual(layout.visibleRows(height: duo.height), perPage * 2)
        XCTAssertEqual(layout.filledRows(atLeast: 1), perPage * 2, "both pages are filled")
        XCTAssertEqual(layout.filledRows(atLeast: perPage * 2 + 1), perPage * 4)
    }

    // MARK: When there is no spread

    func testNoSpreadWithoutAUsableFold() {
        XCTAssertFalse(BoardLayout.make(size: duo, fold: nil).isSpread)
        // Halves too narrow for a page.
        XCTAssertFalse(BoardLayout.make(size: CGSize(width: 500, height: 600), fold: 248...252).isSpread)
        // A fold at the edge is not a fold.
        XCTAssertFalse(BoardLayout.make(size: duo, fold: 0...5).isSpread)
    }

    // MARK: Games

    func testGamePiecesUseTheGridLayout() {
        for layout in [spread, BoardLayout.single(width: 440)] {
            let context = TileGameContext(size: duo, layout: layout)
            XCTAssertEqual(context.cellSize, layout.cellSide)
            XCTAssertEqual(context.pitch, layout.pitch)
            XCTAssertEqual(context.boardLeading, layout.pageX[0])
            for cell in 0..<40 {
                XCTAssertEqual(context.center(of: cell), layout.center(of: cell))
                XCTAssertEqual(context.cell(at: layout.center(of: cell)), cell)
            }
        }
    }
}
