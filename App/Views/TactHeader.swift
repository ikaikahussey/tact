import SwiftUI

/// Sizes shared by the header and its icons.
enum HeaderMetrics {
    static let height: CGFloat = 44
    static let logoHeight: CGFloat = 28
}

/// The one-row header every screen uses in place of a navigation bar:
/// the Tact mark (tap to return to the root grid), the view name in
/// Helvetica Bold, and the screen's icons on the right. When a search
/// binding is given and `isSearching` is on, the name gives way to an
/// inline search field. Pushed screens show a back chevron first.
struct TactHeader<Trailing: View>: View {
    let title: String
    var showsBack = false
    var searchText: Binding<String>? = nil
    var isSearching: Binding<Bool>? = nil
    var onLogoTap: () -> Void = {}
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dismiss) private var dismiss
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
                TactLogo(variant: .mark, height: HeaderMetrics.logoHeight)
                    .frame(height: HeaderMetrics.height)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Tact")
            .accessibilityHint("Returns to the People grid")

            if searching, let searchText {
                searchField(searchText)
            } else {
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
        .padding(.horizontal, 12)
        .background(Color.tactBackground)
        .onChange(of: searching) { _, now in
            searchFocused = now
        }
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
                .frame(width: 40, height: HeaderMetrics.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Lays a screen out under the shared header with the system bar hidden.
struct HeaderScreen<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header()
            content()
        }
        .background(Color.tactBackground)
        .toolbar(.hidden, for: .navigationBar)
    }
}
