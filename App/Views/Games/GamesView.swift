import SwiftUI

/// The back of the tiles: every game, laid over the People grid, each face
/// up only while the tiles are turned over and it is the chosen one. All
/// stay loaded so each keeps its progress. A game is played on the cells
/// that have a tile; one that needs more tiles than there are shows a
/// notice over the grid instead, and the tiles stay face up.
struct GamesSurface: View {
    @EnvironmentObject private var store: TactStore
    let showing: Bool
    let selectedGameID: String

    /// The cells with a people tile, in cell order.
    private var activeCells: [Int] { TileLayout.anchors(for: store.people).values.sorted() }

    /// Whether the chosen game has the tiles it needs. The grid flips its
    /// tiles only when this is true.
    static func isAvailable(gameID: String, tileCount: Int) -> Bool {
        TileGame.named(gameID).isAvailable(tileCount: tileCount)
    }

    var body: some View {
        let cells = activeCells
        let chosen = TileGame.named(selectedGameID)
        let available = chosen.isAvailable(tileCount: cells.count)
        GeometryReader { geometry in
            ForEach(TileGame.all) { game in
                let isShowing = showing && available && chosen.id == game.id
                game.board(TileGameContext(size: geometry.size, isShowing: isShowing,
                                           flipDelay: { TileFlipFace.delay(forCell: $0, columns: TileLayout.columns) },
                                           activeCells: cells))
                    .allowsHitTesting(isShowing)
                    .accessibilityHidden(!isShowing)
            }
        }
        .overlay {
            if showing && !available {
                notice(for: chosen, tileCount: cells.count)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showing && !available)
    }

    /// The notice for a game that needs more tiles, over the dimmed grid.
    private func notice(for game: TileGame, tileCount: Int) -> some View {
        ZStack {
            Color.tactBackground.opacity(0.82)
            ContentUnavailableView {
                Label(game.title, systemImage: game.systemImage)
            } description: {
                Text(game.unavailableText(tileCount: tileCount))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
