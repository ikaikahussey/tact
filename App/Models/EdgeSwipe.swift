import CoreGraphics

/// Swiping in from a screen edge switches between the tiles and the list:
/// from the right edge, leftward, the list slides in over the tiles (or a
/// game's back of the tiles); from the left edge, rightward, it slides back.
enum EdgeSwipe {
    /// How far from the edge a swipe must start.
    static let edgeWidth: CGFloat = 24
    /// How far it must travel, or how fast it must be headed, to switch.
    static let minimumTravel: CGFloat = 60
    static let minimumPredictedTravel: CGFloat = 140

    /// The layout a finished swipe moves to, or nil when it does nothing.
    /// - Parameters:
    ///   - startX: where the touch began, in the container's coordinates.
    ///   - translation: how far it moved.
    ///   - predictedTranslation: where it was headed when lifted.
    ///   - width: the container's width.
    static func target(from layout: PeopleLayout,
                       startX: CGFloat,
                       translation: CGSize,
                       predictedTranslation: CGSize,
                       width: CGFloat) -> PeopleLayout? {
        guard width > 0 else { return nil }
        // Mostly sideways, not a scroll.
        guard abs(translation.width) > abs(translation.height) * 1.5 else { return nil }
        let travelled = abs(translation.width) >= minimumTravel
            || abs(predictedTranslation.width) >= minimumPredictedTravel
        guard travelled else { return nil }

        switch layout.resolved {
        case .grid, .games:
            let fromRight = startX >= width - edgeWidth
            return fromRight && translation.width < 0 && predictedTranslation.width < 0 ? .list : nil
        case .list:
            let fromLeft = startX <= edgeWidth
            return fromLeft && translation.width > 0 && predictedTranslation.width > 0 ? .grid : nil
        default:
            return nil
        }
    }

    /// Whether a touch at `startX` could begin an edge swipe from `layout`,
    /// so the gesture only claims touches at the edge that matters.
    static func begins(in layout: PeopleLayout, startX: CGFloat, width: CGFloat) -> Bool {
        switch layout.resolved {
        case .grid, .games: return startX >= width - edgeWidth
        case .list:         return startX <= edgeWidth
        default:            return false
        }
    }
}
