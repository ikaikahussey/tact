import Foundation

/// Games offered from the People menu. A new game is a case here plus either
/// its own view or a mode of the Tiles grid.
enum Game: String, CaseIterable, Identifiable {
    /// A sliding puzzle played on the people tiles themselves.
    case artPuzzle
    /// Seven people become the seven tangram pieces.
    case tangram

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artPuzzle: return "Art Puzzle"
        case .tangram: return "Tangram"
        }
    }

    /// Whether the game is played on the Tiles grid rather than its own screen.
    var playsInTiles: Bool { self == .artPuzzle }

    var systemImage: String {
        switch self {
        case .artPuzzle: return "puzzlepiece"
        case .tangram: return "triangle"
        }
    }
}
