import SwiftUI

/// One face of a grid cell that turns over on its vertical axis. The face
/// being hidden turns away first, then the other turns into view; `delay`
/// staggers the cells so the flip ripples across the grid. With Reduce
/// Motion the faces cross-fade instead.
struct TileFlipFace: ViewModifier {
    enum Side { case front, back }

    let side: Side
    let showingBack: Bool
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long each face takes to turn through 90°.
    static let halfDuration = 0.16

    /// Stagger for the cell at `index` in a grid with `columns` columns: a
    /// diagonal wave from the top-left corner.
    static func delay(forCell index: Int, columns: Int) -> Double {
        Double(index / columns + index % columns) * 0.035
    }

    private var isVisible: Bool { (side == .back) == showingBack }

    /// The hidden face waits edge-on, on the far side of the turn.
    private var angle: Double {
        guard !isVisible, !reduceMotion else { return 0 }
        return side == .front ? 90 : -90
    }

    private var animation: Animation {
        let half = Self.halfDuration
        if reduceMotion { return .easeInOut(duration: half * 2).delay(delay) }
        // The arriving face starts once the leaving face is edge-on.
        return isVisible ? .easeOut(duration: half).delay(delay + half) : .easeIn(duration: half).delay(delay)
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(isVisible || !reduceMotion ? 1 : 0)
            .animation(animation, value: showingBack)
    }
}
