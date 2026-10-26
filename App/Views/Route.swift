import Foundation

/// Every screen the root navigation stack can push. Value-based so the
/// header's logo can pop the whole stack at once.
enum Route: Hashable {
    case person(UUID)
    case note(UUID)
}

/// Which picture the sliding puzzle cuts up.
enum PuzzleImageSource: Hashable {
    /// The photo chosen in Settings, or the Tact tiles.
    case standard
    /// A person's photo; the Tact tiles when they have none.
    case person(UUID)
}
