import SwiftUI

/// The Tact logo: TACT spelled in solid square tiles of the palette colours.
/// Each letter is 3 tiles wide and 4 tall, with an empty column between
/// letters, on a 15 × 4 grid.
enum TactLogoGrid {
    struct Tile: Equatable, Hashable {
        let column: Int
        let row: Int
        /// Index into `TilePalette`.
        let colorIndex: Int
    }

    static let columns = 15
    static let rows = 4

    /// Rows top to bottom; each character is a `TilePalette` colour, "." is empty.
    private static let map = [
        "CGP.GPG.PVC.TWT",
        ".B..B.B.G....V.",
        ".W..WCW.B....P.",
        ".V..V.V.WPG..G.",
    ]

    /// Map letters to `TilePalette` indexes.
    private static let palette: [Character: Int] = [
        "C": 0,   // coral
        "G": 3,   // green
        "T": 4,   // teal
        "B": 5,   // blue
        "V": 6,   // violet
        "P": 7,   // pink
        "W": 10,  // brown
    ]

    static let tiles: [Tile] = map.enumerated().flatMap { row, line in
        line.enumerated().compactMap { column, character in
            palette[character].map { Tile(column: column, row: row, colorIndex: $0) }
        }
    }

    /// The mark is the first T on its own.
    static let markColumns = 3
    static let markTiles: [Tile] = tiles.filter { $0.column < markColumns }
}

/// Draws the Tact logo as tiles. `.wordmark` is the whole word; `.mark` is
/// the first T. `tileColor` lets a theme supply its own colours.
struct TactLogo: View {
    enum Variant { case wordmark, mark }

    var variant: Variant = .wordmark
    var height: CGFloat = 16
    var tileColor: (Int) -> Color = { TilePalette.color($0) }

    private var columns: Int { variant == .wordmark ? TactLogoGrid.columns : TactLogoGrid.markColumns }
    private var tiles: [TactLogoGrid.Tile] { variant == .wordmark ? TactLogoGrid.tiles : TactLogoGrid.markTiles }
    private var pitch: CGFloat { height / CGFloat(TactLogoGrid.rows) }

    var body: some View {
        Canvas { context, _ in
            // The gap is 12% of the pitch, split evenly around each tile.
            let inset = pitch * 0.06
            let side = pitch - inset * 2
            for tile in tiles {
                let rect = CGRect(x: CGFloat(tile.column) * pitch + inset,
                                  y: CGFloat(tile.row) * pitch + inset,
                                  width: side, height: side)
                context.fill(Path(rect), with: .color(tileColor(tile.colorIndex)))
            }
        }
        .frame(width: pitch * CGFloat(columns), height: height)
        .accessibilityElement()
        .accessibilityLabel("Tact")
        .accessibilityAddTraits(.isImage)
    }
}
