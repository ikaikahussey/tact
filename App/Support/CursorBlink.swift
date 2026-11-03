import SwiftUI

/// Blinks a view on and off like an old terminal cursor: a hard cut, no
/// fade. With Reduce Motion it stays on.
struct CursorBlink: ViewModifier {
    /// A classic cursor's half period.
    static let interval = 0.53

    @State private var isOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isOn || reduceMotion ? 1 : 0)
            .task(id: reduceMotion) {
                isOn = true
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.interval))
                    guard !Task.isCancelled else { return }
                    var noAnimation = Transaction()
                    noAnimation.disablesAnimations = true
                    withTransaction(noAnimation) { isOn.toggle() }
                }
            }
    }
}

extension View {
    func cursorBlink() -> some View { modifier(CursorBlink()) }
}
