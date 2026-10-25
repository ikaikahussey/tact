import SwiftUI

/// The woodblock picture puzzle as a game on the back of Tiles: the sliding
/// board over the top four rows, the move count under it, and buttons to
/// choose the picture or start again.
struct WoodblockPuzzleGame: View {
    @EnvironmentObject private var store: TactStore
    let context: TileGameContext
    @State private var game = PuzzleGame()
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            PuzzleBoard(game: game, pitch: context.pitch, pieceSize: context.cellSize,
                        isShowing: context.isShowing, flipDelay: context.flipDelay)

            status
                .frame(width: context.size.width - 32, alignment: .leading)
                .offset(x: 16, y: CGFloat(ArtPuzzle.rows) * context.pitch + 12)
                .opacity(context.isShowing ? 1 : 0)
                .animation(.easeInOut(duration: 0.2).delay(context.isShowing ? 0.35 : 0), value: context.isShowing)
                .accessibilityHidden(!context.isShowing)
        }
        .frame(width: context.size.width, height: context.size.height, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if context.isShowing {
                HStack(spacing: 12) {
                    CanvasActionButton(title: "Choose Photo", systemImage: "photo",
                                       hint: "Picks the picture for the puzzle.") {
                        showingSettings = true
                    }
                    CanvasActionButton(title: "New Game", systemImage: "shuffle",
                                       hint: "Scrambles the puzzle and starts again.") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { game.newGame() }
                    }
                }
                .padding(16)
                .padding(.trailing, context.trailingControlInset)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.isShowing)
        .onChange(of: store.settings.artSettings.imageData) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { game.newGame() }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                ArtSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            if game.isSolved {
                Label("Solved in \(game.movesText)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
            } else {
                Text(game.movesText)
                    .foregroundStyle(.secondary)
            }
            if game.moveCount == 0 || game.isSolved {
                Text("Drag the pieces into the empty space to rebuild the picture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.isSolved)
    }
}
