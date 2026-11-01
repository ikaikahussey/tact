import SwiftUI

/// A game played on the back of the People tiles. Choosing one from the
/// Games menu turns the tiles over, and the game's pieces turn into view in
/// their place: a game is played on the cells that have a tile, one piece
/// per person, so the pieces are exactly the tiles that turned. A game
/// that needs a set board, like the Sliding Puzzle's sixteen pieces, says
/// how many tiles it takes and waits until there are that many.
///
/// To add a game, write a view that takes a `TileGameContext` and list it
/// in `TileGame.all`. The view draws on the same four-column grid as the
/// tiles, on the context's `activeCells`, and turns its pieces with
/// `TileFlipFace(side: .back, …)` using the context's `isShowing` and
/// `flipDelay`. Every game stays loaded while the tiles are open, so each
/// keeps its progress.
struct TileGame: Identifiable {
    let id: String
    let title: String
    let blurb: String
    let systemImage: String
    /// People tiles the game needs before it can be played.
    var minimumTiles = 1
    let board: (TileGameContext) -> AnyView

    /// Whether the game can be played with `tileCount` people tiles.
    func isAvailable(tileCount: Int) -> Bool { tileCount >= minimumTiles }

    /// What to say while there are too few tiles for the game.
    func unavailableText(tileCount: Int) -> String {
        let need = minimumTiles == 1 ? "a people tile" : "\(minimumTiles) people tiles"
        let have = tileCount == 0 ? "none yet" : tileCount == 1 ? "1 so far" : "\(tileCount) so far"
        return "Available once you have \(need); you have \(have)."
    }

    /// The games offered, in the order of the menu. The first is the default.
    /// Tangram and Lights Out are kept but not offered.
    static let all: [TileGame] = [.slidingPuzzle, .simon, .mosaic]

    static let storageKey = "tilesGame"

    /// The game with `id`, or the first game when there is none.
    static func named(_ id: String) -> TileGame {
        all.first { $0.id == id } ?? all[0]
    }

    static let tangram = TileGame(id: "tangram", title: "Tangram",
                                  blurb: "Everyone as a pattern block. Drag the pieces around the table or fit them together.",
                                  systemImage: "square.split.diagonal.2x2") {
        AnyView(TangramGridContent(context: $0))
    }

    static let slidingPuzzle = TileGame(id: "woodblock", title: "Sliding Puzzle",
                                        blurb: "A picture cut into sixteen pieces, one missing. Slide them back into place. Needs sixteen tiles.",
                                        systemImage: "puzzlepiece", minimumTiles: ArtPuzzle.pieceCount) {
        AnyView(SlidingPuzzleGame(context: $0, source: .standard))
    }

    static let lightsOut = TileGame(id: "lightsout", title: "Lights Out",
                                    blurb: "Sixteen lights, one per tile. Tap one and its neighbours flip too. Turn them all off.",
                                    systemImage: "lightbulb", minimumTiles: 16) {
        AnyView(LightsOutGame(context: $0))
    }

    static let simon = TileGame(id: "simon", title: "Simon",
                                blurb: "Every tile a pad, each a note. Play them like a keyboard, or press play and repeat what Simon plays.",
                                systemImage: "pianokeys") {
        AnyView(SimonGame(context: $0))
    }

    static let mosaic = TileGame(id: "mosaic", title: "Mosaic",
                                 blurb: "A quilt laid over everyone's tiles from their motifs. Stamp, turn and fill the canvas, or draw a stamp of your own in FatBits; it keeps.",
                                 systemImage: "square.grid.3x3.square") {
        AnyView(MosaicGame(context: $0))
    }
}

/// What a game is given to draw with on the back of the tiles.
struct TileGameContext {
    /// Size of the canvas the game fills.
    let size: CGSize
    /// Whether this game is face up: the tiles are turned over and it is chosen.
    var isShowing = true
    /// Stagger for the flip, by cell in a four-column grid.
    var flipDelay: (Int) -> Double = { _ in 0 }
    /// The cells that have a people tile, in cell order: where the game's
    /// pieces go, since each is the back of a tile.
    var activeCells: [Int] = []

    static let columns = TileLayout.columns
    static let spacing: CGFloat = 1

    /// Rows the active cells span, down to the lowest tile.
    var activeRows: Int { activeCells.max().map { $0 / Self.columns + 1 } ?? 0 }

    /// The middle of a cell on the canvas.
    func center(of cell: Int) -> CGPoint {
        CGPoint(x: CGFloat(cell % Self.columns) * pitch + cellSize / 2,
                y: CGFloat(cell / Self.columns) * pitch + cellSize / 2)
    }

    /// Side of one cell, matching the Tiles grid so pieces land on the tiles.
    var cellSize: CGFloat {
        ((size.width - Self.spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)).rounded(.down)
    }

    /// Distance from one cell to the next.
    var pitch: CGFloat { cellSize + Self.spacing }
}
