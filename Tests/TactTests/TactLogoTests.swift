import XCTest
import SwiftUI
@testable import Tact

final class TactLogoTests: XCTestCase {
    private func occupied(_ tiles: [TactLogoGrid.Tile]) -> Set<[Int]> {
        Set(tiles.map { [$0.column, $0.row] })
    }

    func testTilesSpellTACT() {
        let tiles = TactLogoGrid.tiles
        XCTAssertEqual(tiles.count, 30)
        XCTAssertEqual(occupied(tiles).count, tiles.count, "no two tiles share a cell")

        // Each letter on its own 3 × 4 block, read as rows of filled cells.
        let letters = [
            "T": ["###", ".#.", ".#.", ".#."],
            "A": ["###", "#.#", "###", "#.#"],
            "C": ["###", "#..", "#..", "###"],
        ]
        let cells = occupied(tiles)
        for (index, letter) in ["T", "A", "C", "T"].enumerated() {
            let firstColumn = index * 4
            let drawn = (0..<TactLogoGrid.rows).map { row in
                String((0..<3).map { cells.contains([firstColumn + $0, row]) ? "#" : "." })
            }
            XCTAssertEqual(drawn, letters[letter], "letter \(index + 1) is \(letter)")
        }
        // The columns between letters are empty.
        for gap in [3, 7, 11] {
            XCTAssertFalse(tiles.contains { $0.column == gap }, "column \(gap) is a gap")
        }
    }

    func testTilesFitTheGridAndPalette() {
        for tile in TactLogoGrid.tiles {
            XCTAssertTrue((0..<TactLogoGrid.columns).contains(tile.column), "\(tile)")
            XCTAssertTrue((0..<TactLogoGrid.rows).contains(tile.row), "\(tile)")
            XCTAssertTrue((0..<TileArt.colorCount).contains(tile.colorIndex), "\(tile)")
        }
    }

    func testTouchingTilesNeverShareAColour() {
        let colors = Dictionary(uniqueKeysWithValues: TactLogoGrid.tiles.map { ([$0.column, $0.row], $0.colorIndex) })
        for tile in TactLogoGrid.tiles {
            for neighbour in [[tile.column + 1, tile.row], [tile.column, tile.row + 1]] {
                if let other = colors[neighbour] {
                    XCTAssertNotEqual(other, tile.colorIndex, "\(tile) touches \(neighbour)")
                }
            }
        }
    }

    func testMarkIsTheFirstT() {
        let mark = TactLogoGrid.markTiles
        XCTAssertEqual(TactLogoGrid.markColumns, 3)
        XCTAssertEqual(mark.count, 6)
        XCTAssertTrue(mark.allSatisfy { $0.column < 3 })
        XCTAssertEqual(occupied(mark), occupied(TactLogoGrid.tiles.filter { $0.column < 3 }))
    }

    func testTypeMetricsFollowTheTextStyles() {
        XCTAssertEqual(TactType.metrics(for: .largeTitle).size, 34)
        XCTAssertTrue(TactType.metrics(for: .headline).isBold)
        XCTAssertEqual(TactType.metrics(for: .body).size, 17)
        XCTAssertFalse(TactType.metrics(for: .body).isBold)
        XCTAssertEqual(TactType.metrics(for: .caption2).size, 11)
        XCTAssertNotNil(UIFont(name: TactType.regular, size: 17), "Helvetica Neue is on the device")
        XCTAssertNotNil(UIFont(name: TactType.bold, size: 17))
    }
}
