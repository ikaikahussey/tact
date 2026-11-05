import SwiftUI

/// Sizes shared by the header and its icons.
enum HeaderMetrics {
    static let height: CGFloat = 44
    static let logoHeight: CGFloat = 28
    static let iconWidth: CGFloat = 44
    /// The least space the wordmark wants above it. In portrait the status
    /// bar's safe area gives more than this; in landscape, where the safe
    /// area is at the sides, the header adds the difference itself.
    static let minimumHeadroom: CGFloat = 20
}

/// A small pill beside the wordmark naming a mode the root is in, such as
/// the game the tiles are turned over to.
struct HeaderBadge: Equatable {
    let title: String
    let systemImage: String
}

/// The one-row header every screen uses in place of a navigation bar:
/// the Tact wordmark (tap to return to the root grid), the view name in
/// Helvetica Bold (none on the root, whose view is picked by the
/// `ViewSwitch` at the bottom), and the screen's icons on the right. On
/// the root a `badge` may sit beside the wordmark while the tiles are
/// turned over to a game. When a search binding is given and
/// `isSearching` is on, the name gives way to an inline search field.
/// Pushed screens show a back chevron first.
struct TactHeader<Trailing: View>: View {
    let title: String
    var showsBack = false
    var searchText: Binding<String>? = nil
    var isSearching: Binding<Bool>? = nil
    var badge: HeaderBadge? = nil
    var onLogoTap: () -> Void = {}
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @FocusState private var searchFocused: Bool

    private var searching: Bool { isSearching?.wrappedValue == true && searchText != nil }

    var body: some View {
        HStack(spacing: 8) {
            if showsBack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.tact(.body).weight(.semibold))
                        .frame(width: 32, height: HeaderMetrics.height)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
            }

            Button(action: onLogoTap) {
                TactLogo(variant: .wordmark, height: HeaderMetrics.logoHeight)
                    .frame(height: HeaderMetrics.height)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Tact")
            .accessibilityHint("Returns to the People grid")

            if searching, let searchText {
                searchField(searchText)
            } else if let badge {
                badgeView(badge)
            } else if !title.isEmpty {
                Text(title)
                    .font(.tact(.title3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                trailing()
            }
        }
        .buttonStyle(.plain)
        .frame(height: HeaderMetrics.height)
        .padding(.horizontal, 10)
        .background(Color.tactBackground)
        .animation(.snappy, value: badge)
        .onChange(of: searching) { _, now in
            searchFocused = now
        }
    }

    /// The mode pill: the game's glyph and name in the accent, saying the
    /// tiles are turned over to it.
    private func badgeView(_ badge: HeaderBadge) -> some View {
        Label(badge.title, systemImage: badge.systemImage)
            .font(.tact(.footnote).weight(.semibold))
            .foregroundStyle(palette.onAccent)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.tint, in: Capsule())
            .lineLimit(1)
            .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
            .accessibilityLabel("Tiles turned over to \(badge.title)")
    }

    private func searchField(_ text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            TextField("Search", text: text)
                .font(.tact(.body))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("Search people and notes")
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.tactTileGray.opacity(0.5), in: Capsule())
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

/// One icon in the header's row of actions.
struct HeaderIconButton: View {
    let title: String
    let systemImage: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.tact(.body).weight(.semibold))
                .symbolVariant(isActive ? .fill : .none)
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: HeaderMetrics.iconWidth, height: HeaderMetrics.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The bottom navigation: one capsule centred at the bottom with People and
/// Notes. The games are the back of the People tiles, so they live in the
/// People segment rather than beside it: with Tiles showing, tapping the
/// segment again lists the games (so does holding it from anywhere), and
/// while a game is up the segment wears that game's glyph and offers the
/// way back, Turn Tiles Over. Pushed screens cover it.
struct ViewSwitch: View {
    @Binding var layout: PeopleLayout
    /// The game on the back of the tiles.
    @Binding var selectedGameID: String
    @Environment(\.appPalette) private var palette

    /// Whether the People tiles are showing, face up or turned to a game.
    private var onTiles: Bool { layout.resolved == .grid || layout.resolved == .games }
    private var game: TileGame? { layout.resolved == .games ? TileGame.named(selectedGameID) : nil }

    var body: some View {
        HStack {
            capsule {
                tilesSegment
                ForEach(PeopleLayout.available.filter { $0 != .games && $0 != .grid }) { option in
                    let isSelected = layout.resolved == option
                    Button {
                        guard !isSelected else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.snappy) { layout = option }
                    } label: {
                        segment(option.switchImage, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.viewTitle)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .accessibilityLabel("View")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    /// People: a tap shows the tiles; on the tiles already, a tap lists the
    /// games on their back, as a hold does from anywhere.
    @ViewBuilder
    private var tilesSegment: some View {
        let label = segment(game?.systemImage ?? PeopleLayout.grid.switchImage, isSelected: onTiles)
            .contentTransition(.symbolEffect(.replace))
        Group {
            if onTiles {
                Menu { gameMenu } label: { label }
            } else {
                // A tap shows the tiles; the menu waits behind a hold.
                Menu { gameMenu } label: { label } primaryAction: {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) { layout = .grid }
                }
            }
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .accessibilityLabel(game.map { "People, tiles turned over to \($0.title)" } ?? "People")
        .accessibilityHint(onTiles ? "Lists the games on the back of the tiles" : "Shows the tiles; hold for the games on their back")
        .accessibilityAddTraits(onTiles ? [.isSelected] : [])
    }

    @ViewBuilder
    private var gameMenu: some View {
        Section("Back of the tiles") {
            ForEach(TileGame.all) { candidate in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    selectedGameID = candidate.id
                    withAnimation(.snappy) { layout = .games }
                } label: {
                    if game?.id == candidate.id {
                        Label(candidate.title, systemImage: "checkmark")
                    } else {
                        Label(candidate.title, systemImage: candidate.systemImage)
                    }
                }
            }
        }
        if game != nil {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.snappy) { layout = .grid }
            } label: {
                Label("Turn Tiles Over", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            }
        }
    }

    private func capsule(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 4, content: content)
            .padding(4)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            .accessibilityElement(children: .contain)
    }

    private func segment(_ systemImage: String, isSelected: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.tact(.body).weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(palette.onAccent) : AnyShapeStyle(.primary))
            .frame(width: 56, height: 44)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: Capsule())
            .contentShape(Capsule())
    }
}

/// Lays a screen out under the shared header with the system bar hidden.
struct HeaderScreen<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header()
                    .padding(.top, max(0, HeaderMetrics.minimumHeadroom - proxy.safeAreaInsets.top))
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.tactBackground)
        .toolbar(.hidden, for: .navigationBar)
    }
}
