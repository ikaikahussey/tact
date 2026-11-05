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

    /// The pill beside the wordmark while the game is up: the tiles are
    /// turned over to it.
    var headerBadge: HeaderBadge { HeaderBadge(title: title, systemImage: systemImage) }

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
    /// Where each cell is drawn: the same layout as the Tiles grid, so
    /// pieces land on the tiles, on one board or across a fold.
    let layout: BoardLayout
    /// Whether this game is face up: the tiles are turned over and it is chosen.
    var isShowing: Bool
    /// Stagger for the flip, by cell in a four-column grid.
    var flipDelay: (Int) -> Double
    /// The cells that have a people tile, in cell order: where the game's
    /// pieces go, since each is the back of a tile.
    var activeCells: [Int]

    init(size: CGSize, layout: BoardLayout? = nil, isShowing: Bool = true,
         flipDelay: @escaping (Int) -> Double = { _ in 0 }, activeCells: [Int] = []) {
        self.size = size
        self.layout = layout ?? .single(width: size.width)
        self.isShowing = isShowing
        self.flipDelay = flipDelay
        self.activeCells = activeCells
    }

    static let columns = TileLayout.columns
    static let spacing = TileLayout.spacing

    /// Rows the active cells span, down to the lowest tile.
    var activeRows: Int { activeCells.max().map { $0 / Self.columns + 1 } ?? 0 }

    /// The middle of a cell on the canvas.
    func center(of cell: Int) -> CGPoint { layout.center(of: cell) }

    /// The cell under a point on the canvas, or nil off the board.
    func cell(at point: CGPoint) -> Int? { layout.cell(at: point) }

    /// How far down the canvas board rows `0..<rows` reach: where a line
    /// under the board goes.
    func bottom(ofRows rows: Int) -> CGFloat { layout.height(rows: rows) }

    /// Leading edge of the first page's board.
    var boardLeading: CGFloat { layout.pageX[0] }

    /// Side of one cell, matching the Tiles grid so pieces land on the tiles.
    var cellSize: CGFloat { layout.cellSide }

    /// Distance from one cell to the next.
    var pitch: CGFloat { layout.pitch }
}
