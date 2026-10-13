import SwiftUI

extension Color {
    static let tactBackground = Color(uiColor: .systemGroupedBackground)
    static let tactSecondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tactCardBackground = Color(uiColor: .systemBackground)
    static let tactTileGray = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.25, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })
}

extension Bundle {
    /// "1.0 (1)" style version string for the About screen.
    var displayVersion: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// Shows "Tact" as the small title in the top bar of every tab. The tab's own
/// large header is drawn in the content by `TabHeader`.
struct AppTitleBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Tact")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

extension View {
    func appTitleBar() -> some View { modifier(AppTitleBar()) }
}

/// Large header at the top of a tab, in the style of a large navigation title.
struct TabHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    init(_ title: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            accessory()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
