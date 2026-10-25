import SwiftUI

/// Shown once, on the empty Tiles canvas, before anyone has been added: a
/// block of demo tiles turns over to the games and back, so the games on the
/// back of Tiles are not a surprise found only after the sixteenth person.
struct GamesIntroView: View {
    static let seenKey = "hasSeenGamesIntro"

    /// Called when the intro is dismissed; `true` if the user chose to add
    /// someone straight away.
    var onDismiss: (_ addSomeone: Bool) -> Void

    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingBack = false

    private let columns = TileLayout.columns
    private var cellCount: Int { ArtPuzzle.pieceCount }

    /// A spread of patterns and colours, fixed so the demo always looks the same.
    private func pattern(_ cell: Int) -> TilePattern {
        TilePattern.allCases[(cell * 3) % TilePattern.allCases.count]
    }

    private func colorIndex(_ cell: Int) -> Int {
        TilePalette.menuOrder[(cell * 5) % TilePalette.menuOrder.count]
    }

    var body: some View {
        VStack(spacing: 24) {
            demoGrid
                .frame(maxWidth: 220)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Everyone Is a Tile")
                    .font(.tact(.title2))
                Text("Add people and each becomes a tile you can color, turn and arrange. Once you have \(cellCount), the tiles flip over to games on the back.")
                    .font(.tact(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    onDismiss(true)
                } label: {
                    Text("Add Someone")
                        .font(.tact(.headline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(palette.onAccent)

                Button("Not Now") { onDismiss(false) }
                    .font(.tact(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Everyone is a tile. Once you have \(cellCount) people, the tiles flip over to games.")
        .task {
            // With Reduce Motion the faces cross-fade once and stay on the games.
            guard !reduceMotion else {
                try? await Task.sleep(for: .seconds(1))
                showingBack = true
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(showingBack ? 2.6 : 1.6))
                showingBack.toggle()
            }
        }
    }

    /// Four rows of four: patterned fronts and game backs, flipping in the
    /// same diagonal wave as the real canvas.
    private var demoGrid: some View {
        let rows = cellCount / columns
        return Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let cell = row * columns + column
                        let delay = TileFlipFace.delay(forCell: cell, columns: columns)
                        ZStack {
                            TilePatternView(pattern: pattern(cell), colorIndex: colorIndex(cell))
                                .modifier(TileFlipFace(side: .front, showingBack: showingBack, delay: delay))
                            back(for: cell)
                                .modifier(TileFlipFace(side: .back, showingBack: showingBack, delay: delay))
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    /// The back of a demo tile: the left half plays the sliding puzzle, the
    /// right half the Tangram, in the accent colour.
    private func back(for cell: Int) -> some View {
        let isTangram = cell % columns >= columns / 2
        return ZStack {
            palette.accent.opacity(0.9)
            Image(systemName: isTangram ? "square.split.diagonal.2x2" : "puzzlepiece")
                .font(.tact(.title3).weight(.semibold))
                .foregroundStyle(palette.onAccent)
                .rotationEffect(.degrees(Double((cell * 7) % 4) * 90))
        }
    }
}
