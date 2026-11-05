import SwiftUI

/// Equal side margins where the safe area is one-sided. In landscape the
/// status bar and the navigation controls take a column at one edge of
/// the screen (the iPhone Duo's inner display keeps them on the right),
/// so a screen padded only by the safe area sits nearer the other edge.
/// This mirrors the wider side inset onto the narrower side so the
/// content is centred between the screen's edges.
private struct BalancedMargins: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            content
                .padding(.leading, max(0, insets.trailing - insets.leading))
                .padding(.trailing, max(0, insets.leading - insets.trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension View {
    /// Pads the narrower side to match the wider side's safe area, so the
    /// left and right margins are equal.
    func balancedMargins() -> some View {
        modifier(BalancedMargins())
    }
}
