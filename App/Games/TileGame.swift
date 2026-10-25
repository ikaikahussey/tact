import SwiftUI

/// A game or puzzle played on the back of the Tiles grid. When the tiles turn
/// over, the chosen game's pieces turn into view in their place.
///
/// To add a game, write a view that takes a `TileGameContext` and list it in
/// `TileGame.all`. The view draws on the same four-column grid as Tiles,
/// turns its pieces with `TileFlipFace(side: .back, …)` using the context's
/// `isShowing` and `flipDelay`, and keeps its buttons clear of the shared
/// controls (`leadingControlInset`, `trailingControlInset`). Every game stays
/// loaded while Tiles is open, so its progress survives flips and switches.
struct TileGame: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let board: (TileGameContext) -> AnyView

    /// The games offered, in the order of the selector. The first is the default.
    static let all: [TileGame] = [.woodblock, .tangram]

    static let storageKey = "tilesGame"

    /// The game with `id`, or the first game when there is none.
    static func named(_ id: String) -> TileGame {
        all.first { $0.id == id } ?? all[0]
    }

    static let woodblock = TileGame(id: "woodblock", title: "Woodblock Puzzle", systemImage: "puzzlepiece") {
        AnyView(WoodblockPuzzleGame(context: $0))
    }

    static let tangram = TileGame(id: "tangram", title: "Tangram", systemImage: "square.split.diagonal.2x2") {
        AnyView(TangramGridContent(context: $0))
    }
}

/// What a game is given to draw with on the back of the Tiles grid.
struct TileGameContext {
    /// Size of the canvas the game fills.
    let size: CGSize
    /// Whether this game is face up: the tiles are turned over and it is chosen.
    let isShowing: Bool
    /// Stagger for the flip, by cell in a four-column grid.
    let flipDelay: (Int) -> Double
    /// Room to leave at the bottom-leading corner for the game selector.
    let leadingControlInset: CGFloat
    /// Room to leave at the bottom-trailing corner for the flip button.
    let trailingControlInset: CGFloat

    static let columns = TileLayout.columns
    static let spacing: CGFloat = 1

    /// Side of one cell, matching the Tiles grid so pieces land on the tiles.
    var cellSize: CGFloat {
        ((size.width - Self.spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)).rounded(.down)
    }

    /// Distance from one cell to the next.
    var pitch: CGFloat { cellSize + Self.spacing }
}
