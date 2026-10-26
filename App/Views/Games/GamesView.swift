import SwiftUI

/// The Games view of the root screen: a card for each game, pushing it.
struct GamesContent: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(TileGame.all) { game in
                    NavigationLink(value: game.route) {
                        card(for: game)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens \(game.title)")
                }
            }
            .padding(16)
        }
    }

    private func card(for game: TileGame) -> some View {
        HStack(spacing: 16) {
            Image(systemName: game.systemImage)
                .font(.tact(.title))
                .foregroundStyle(palette.onAccent)
                .frame(width: 64, height: 64)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title).font(.tact(.headline))
                Text(game.blurb)
                    .font(.tact(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.tact(.caption).weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tactCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A game under the shared header, given the canvas size to draw in.
struct GameScreen<Game: View>: View {
    let title: String
    var onLogoTap: () -> Void = {}
    @ViewBuilder var game: (TileGameContext) -> Game

    var body: some View {
        HeaderScreen {
            TactHeader(title: title, showsBack: true, onLogoTap: onLogoTap) { EmptyView() }
        } content: {
            GeometryReader { geometry in
                game(TileGameContext(size: geometry.size))
            }
        }
    }
}
