import SwiftUI

/// The back of the tiles: every game, laid over the People grid, each face
/// up only while the tiles are turned over and it is the chosen one. All
/// stay loaded so each keeps its progress.
struct GamesSurface: View {
    let showing: Bool
    let selectedGameID: String

    var body: some View {
        GeometryReader { geometry in
            ForEach(TileGame.all) { game in
                let isShowing = showing && TileGame.named(selectedGameID).id == game.id
                game.board(TileGameContext(size: geometry.size, isShowing: isShowing,
                                           flipDelay: { TileFlipFace.delay(forCell: $0, columns: TileLayout.columns) }))
                    .allowsHitTesting(isShowing)
                    .accessibilityHidden(!isShowing)
            }
        }
    }
}
