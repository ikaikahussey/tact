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
