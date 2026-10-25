import Foundation

/// Web addresses the app links to. App Review requires the privacy policy to
/// be reachable from inside the app as well as from the App Store listing.
enum TactLinks {
    /// Set this to the published privacy policy before submitting; it must
    /// match the Privacy Policy URL entered in App Store Connect.
    static let privacyPolicy = URL(string: "https://tact.bitrig.app/privacy")!
}
