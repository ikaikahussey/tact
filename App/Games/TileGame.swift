import SwiftUI

/// A game listed on the Games screen. Each draws on the same four-column
/// grid as the People tiles, given a `TileGameContext` for the canvas size.
struct TileGame: Identifiable {
    let id: String
    let title: String
    let blurb: String
    let systemImage: String
    let route: Route

    /// The games offered, in the order of their cards.
    static let all: [TileGame] = [.tangram, .slidingPuzzle]

    static let tangram = TileGame(id: "tangram", title: "Tangram",
                                  blurb: "Everyone as a pattern block. Drag the pieces around the table or fit them together.",
                                  systemImage: "square.split.diagonal.2x2", route: .tangram)

    static let slidingPuzzle = TileGame(id: "woodblock", title: "Sliding Puzzle",
                                        blurb: "A picture cut into sixteen pieces, one missing. Slide them back into place.",
                                        systemImage: "puzzlepiece", route: .slidingPuzzle(.standard))
}

/// What a game is given to draw with.
struct TileGameContext {
    /// Size of the canvas the game fills.
    let size: CGSize
    /// Whether the game is on screen. Always true now that games have their
    /// own screen; kept so the pieces' flip-in animation can be reused.
    var isShowing = true
    /// Stagger for the flip, by cell in a four-column grid.
    var flipDelay: (Int) -> Double = { _ in 0 }
    /// Room to leave at the bottom corners for other controls.
    var leadingControlInset: CGFloat = 0
    var trailingControlInset: CGFloat = 0

    static let columns = TileLayout.columns
    static let spacing: CGFloat = 1

    /// Side of one cell, matching the Tiles grid so pieces land on the tiles.
    var cellSize: CGFloat {
        ((size.width - Self.spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)).rounded(.down)
    }

    /// Distance from one cell to the next.
    var pitch: CGFloat { cellSize + Self.spacing }
}
