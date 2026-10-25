import SwiftUI
import UIKit

/// The picture the Sliding Puzzle uses unless a photo is chosen: the four
/// letters of the Tact logo, each in its own quarter of a square, drawn as
/// tiles in the palette colours on a faint grid. The letters straddle the
/// puzzle's cuts, so every piece shows part of one.
enum TactTilesImage {
    static let side: CGFloat = 1024

    /// Cells per quarter, across and down. The 3 × 4 letter sits centred.
    static let cellsPerQuarter = 8

    static var data: Data { data(for: .current) }

    private static var cache: [AppPalette: Data] = [:]

    static func data(for palette: AppPalette) -> Data {
        if let cached = cache[palette] { return cached }
        let data = render(palette: palette)
        cache[palette] = data
        return data
    }

    /// The tiles of each letter, by letter position, in the logo's grid.
    static func letterTiles() -> [[TactLogoGrid.Tile]] {
        (0..<4).map { index in
            let first = index * 4
            return TactLogoGrid.tiles
                .filter { $0.column >= first && $0.column < first + 3 }
                .map { TactLogoGrid.Tile(column: $0.column - first, row: $0.row, colorIndex: $0.colorIndex) }
        }
    }

    private static func render(palette: AppPalette) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let quarter = side / 2
        let pitch = quarter / CGFloat(cellsPerQuarter)
        let gap = pitch * 0.08
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            // The grid behind the letters.
            UIColor(white: 0.9, alpha: 1).setFill()
            for row in 0..<(cellsPerQuarter * 2) {
                for column in 0..<(cellsPerQuarter * 2) {
                    context.fill(CGRect(x: CGFloat(column) * pitch + gap, y: CGFloat(row) * pitch + gap,
                                        width: pitch - gap * 2, height: pitch - gap * 2))
                }
            }
            for (index, tiles) in letterTiles().enumerated() {
                let origin = CGPoint(x: CGFloat(index % 2) * quarter + (quarter - 3 * pitch) / 2,
                                     y: CGFloat(index / 2) * quarter + (quarter - 4 * pitch) / 2)
                for tile in tiles {
                    UIColor(palette.tileColor(tile.colorIndex)).setFill()
                    context.fill(CGRect(x: origin.x + CGFloat(tile.column) * pitch + gap,
                                        y: origin.y + CGFloat(tile.row) * pitch + gap,
                                        width: pitch - gap * 2, height: pitch - gap * 2))
                }
            }
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
