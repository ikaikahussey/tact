import CoreGraphics

/// Swiping in from a screen edge switches between the tiles and the list:
/// from the right edge, leftward, the list slides in over the tiles (or a
/// game's back of the tiles); from the left edge, rightward, it slides back.
/// The screen follows the finger, and lifting it either finishes the move
/// or lets it settle back.
enum EdgeSwipe {
    enum Side { case leading, trailing }

    /// The width of the strip at the edge that owns the swipe. Touches that
    /// start here never reach the tiles or rows beneath.
    static let edgeWidth: CGFloat = 20
    /// How far it must travel, as a share of the width, or how far it was
    /// headed when lifted, to switch.
    static let commitFraction: CGFloat = 0.3
    static let minimumPredictedTravel: CGFloat = 160

    /// Which edge the swipe starts from in `layout`, or nil when none does.
    static func side(for layout: PeopleLayout) -> Side? {
        switch layout.resolved {
        case .grid, .games: return .trailing
        case .list:         return .leading
        default:            return nil
        }
    }

    /// How far across the screen is, 0 for the tiles and 1 for the list,
    /// while the finger is `translationX` from where it began.
    static func progress(from layout: PeopleLayout, translationX: CGFloat, width: CGFloat) -> CGFloat? {
        guard width > 0, let side = side(for: layout) else { return nil }
        let moved = min(max(abs(translationX) / width, 0), 1)
        switch side {
        case .trailing: return translationX < 0 ? moved : 0
        case .leading:  return translationX > 0 ? 1 - moved : 1
        }
    }

    /// The layout a finished swipe moves to, or nil when it settles back.
    static func target(from layout: PeopleLayout,
                       translation: CGSize,
                       predictedTranslation: CGSize,
                       width: CGFloat) -> PeopleLayout? {
        guard width > 0, let side = side(for: layout) else { return nil }
        // Mostly sideways.
        guard abs(translation.width) > abs(translation.height) else { return nil }
        let sign: CGFloat = side == .trailing ? -1 : 1
        let moved = translation.width * sign
        let headed = predictedTranslation.width * sign
        // A flick back cancels, however far it went.
        guard moved > 0, headed > 0 else { return nil }
        guard moved >= width * commitFraction || headed >= minimumPredictedTravel else { return nil }
        return side == .trailing ? .list : .grid
    }
}
