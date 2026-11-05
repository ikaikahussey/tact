import XCTest
import CoreGraphics
@testable import Tact

/// Tile size on canvases from the smallest iPhone to the iPhone Duo's inner
/// display. The grid and the games both size and place their boards with
/// these, so they must agree for pieces to land on tiles.
final class TileSizingTests: XCTestCase {
    /// Canvas widths in points: iPhone SE, iPhone 17, iPhone 17 Pro Max,
    /// iPhone Duo outer display.
    private let narrowWidths: [CGFloat] = [375, 402, 440, 466]
    /// iPhone Duo inner display, portrait and landscape.
    private let wideWidths: [CGFloat] = [669, 951]

    func testNarrowCanvasesStillFillFourAcross() {
        for width in narrowWidths {
            let side = TileLayout.cellSide(forWidth: width)
            XCTAssertLessThan(side, TileLayout.maxCellSide, "\(width)")
            XCTAssertEqual(side, ((width - 3) / 4).rounded(.down), "\(width): unchanged from before the cap")
            XCTAssertLessThanOrEqual(TileLayout.boardWidth(cellSide: side), width, "\(width)")
            XCTAssertLessThanOrEqual(TileLayout.inset(forWidth: width, cellSide: side), 1, "\(width): board fills the width")
        }
    }

    func testWideCanvasesCapTheTileAndCentreTheBoard() {
        for width in wideWidths {
            let side = TileLayout.cellSide(forWidth: width)
            XCTAssertEqual(side, TileLayout.maxCellSide, "\(width)")
            let board = TileLayout.boardWidth(cellSide: side)
            let inset = TileLayout.inset(forWidth: width, cellSide: side)
            XCTAssertEqual(board, side * 4 + TileLayout.spacing * 3)
            XCTAssertEqual(inset, inset.rounded(.down), "whole points")
            XCTAssertLessThanOrEqual(abs((width - board - inset) - inset), 1, "\(width): centred")
        }
    }

    func testCellSideIsWholePointsAndNeverNegative() {
        for width in [0, 1, 2, 3.5, 100.7, 669.3] as [CGFloat] {
            let side = TileLayout.cellSide(forWidth: width)
            XCTAssertGreaterThanOrEqual(side, 0, "\(width)")
            XCTAssertEqual(side, side.rounded(.down), "\(width)")
            XCTAssertGreaterThanOrEqual(TileLayout.inset(forWidth: width, cellSide: side), 0, "\(width)")
        }
    }

    /// A game's board is the grid's board: its cell size from the board
    /// width matches the grid's cell size from the full canvas width.
    func testGameBoardCellsMatchGridCells() {
        for width in narrowWidths + wideWidths {
            let side = TileLayout.cellSide(forWidth: width)
            let board = TileLayout.boardWidth(cellSide: side)
            let context = TileGameContext(size: CGSize(width: board, height: 800))
            XCTAssertEqual(context.cellSize, side, "\(width)")
            XCTAssertEqual(context.pitch, side + TileLayout.spacing, "\(width)")
        }
    }
}
