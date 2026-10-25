import SwiftUI

/// The state of one Puzzle game, kept while its screen is open.
@Observable
final class PuzzleGame {
    private(set) var puzzle = ArtPuzzle.makePuzzle()
    private(set) var moveCount = 0

    init() { newGame() }

    var isSolved: Bool { puzzle.isSolved }
    var movesText: String { moveCount == 1 ? "1 move" : "\(moveCount) moves" }

    /// Slides the run starting at `slot`. Returns `false` if nothing moved.
    @discardableResult
    func move(from slot: Int) -> Bool {
        guard puzzle.tap(slot) else { return false }
        moveCount += 1
        return true
    }

    func newGame() {
        var fresh = ArtPuzzle.makePuzzle()
        fresh.shuffle()
        puzzle = fresh
        moveCount = 0
    }
}

/// The sliding picture puzzle on the four-column grid: the picture is cut
/// into a 4×4 grid with one piece missing, scrambled, and restored by
/// dragging pieces into the empty space. Dragging a piece that cannot move
/// gives a small bump instead.
struct PuzzleBoard: View {
    let game: PuzzleGame
    /// The picture being rebuilt.
    let imageData: Data
    /// Distance from one cell to the next.
    let pitch: CGFloat
    let pieceSize: CGFloat

    // Drag state. Offsets apply to `draggedTiles` along one axis.
    @State private var draggedTiles: Set<Int> = []
    @State private var dragHorizontal = true
    @State private var dragSign: CGFloat = 1
    @State private var dragAmount: CGFloat = 0
    @State private var bumpedTile: Int?
    @State private var bumpOffset: CGSize = .zero

    private let columns = ArtPuzzle.columns
    private let commitAnimation = Animation.spring(response: 0.32, dampingFraction: 0.78)

    private var puzzle: SlidingPuzzle<Int> { game.puzzle }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(puzzle.tiles, id: \.self) { tile in
                if let slot = puzzle.slot(of: tile) {
                    pieceView(index: tile)
                        .position(center(of: slot))
                        .offset(offset(for: tile))
                        .zIndex(draggedTiles.contains(tile) || bumpedTile == tile ? 1 : 0)
                        .gesture(dragGesture(for: tile))
                        .onTapGesture { tapped(tile) }
                        .accessibilityLabel("Piece \(tile + 1)")
                        .accessibilityHint("Drag or double-tap to slide toward the empty space")
                }
            }
            if game.isSolved {
                // Fill the empty space so the finished picture is whole.
                pieceView(index: puzzle.tiles.count)
                    .position(center(of: puzzle.blankIndex))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(width: pitch * CGFloat(columns), height: pitch * CGFloat(ArtPuzzle.rows), alignment: .topLeading)
        .animation(commitAnimation, value: game.isSolved)
    }

    @ViewBuilder
    private func pieceView(index: Int) -> some View {
        Group {
            if let image = ArtImageCache.shared.tile(for: imageData, index: index, tileCount: ArtPuzzle.pieceCount) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.tactCardBackground
            }
        }
        .frame(width: pieceSize, height: pieceSize)
        .clipped()
    }

    // MARK: Geometry

    private func center(of slot: Int) -> CGPoint {
        CGPoint(x: CGFloat(slot % columns) * pitch + pieceSize / 2,
                y: CGFloat(slot / columns) * pitch + pieceSize / 2)
    }

    private func offset(for tile: Int) -> CGSize {
        if bumpedTile == tile { return bumpOffset }
        guard draggedTiles.contains(tile) else { return .zero }
        let distance = dragAmount * dragSign
        return dragHorizontal ? CGSize(width: distance, height: 0) : CGSize(width: 0, height: distance)
    }

    // MARK: Interaction

    private func dragGesture(for tile: Int) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if draggedTiles.isEmpty && bumpedTile == nil {
                    beginDrag(tile: tile)
                }
                if draggedTiles.contains(tile) {
                    let raw = dragHorizontal ? value.translation.width : value.translation.height
                    dragAmount = min(pitch, max(0, raw * dragSign))
                } else if bumpedTile == tile {
                    // Resist: the piece nudges a few points and no more.
                    let resistance: CGFloat = 0.18, limit: CGFloat = 10
                    bumpOffset = CGSize(width: max(-limit, min(limit, value.translation.width * resistance)),
                                        height: max(-limit, min(limit, value.translation.height * resistance)))
                }
            }
            .onEnded { value in
                if draggedTiles.contains(tile) {
                    let raw = dragHorizontal ? value.predictedEndTranslation.width : value.predictedEndTranslation.height
                    let predicted = raw * dragSign
                    if dragAmount > pitch * 0.4 || predicted > pitch * 0.6 {
                        commitMove(from: tile)
                    } else {
                        withAnimation(commitAnimation) { dragAmount = 0 }
                    }
                } else if bumpedTile == tile {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bumpOffset = .zero }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if bumpOffset == .zero { bumpedTile = nil }
                    }
                }
            }
    }

    private func beginDrag(tile: Int) {
        guard !game.isSolved, let slot = puzzle.slot(of: tile) else { return }
        if let direction = puzzle.moveDirection(from: slot) {
            draggedTiles = Set(puzzle.run(from: slot).compactMap { puzzle.slots[$0] })
            dragHorizontal = direction.horizontal
            dragSign = CGFloat(direction.sign)
            dragAmount = 0
        } else {
            bumpedTile = tile
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
        }
    }

    private func tapped(_ tile: Int) {
        guard !game.isSolved, let slot = puzzle.slot(of: tile) else { return }
        if puzzle.moveDirection(from: slot) != nil {
            draggedTiles = Set(puzzle.run(from: slot).compactMap { puzzle.slots[$0] })
            dragAmount = 0
            commitMove(from: tile)
        } else {
            bump(tile)
        }
    }

    /// Slides the run into the blank. The slot change and the drag offset are
    /// animated together so the pieces finish their motion without jumping.
    private func commitMove(from tile: Int) {
        guard let slot = puzzle.slot(of: tile) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(commitAnimation) {
            game.move(from: slot)
            dragAmount = 0
        }
        draggedTiles = []
        if game.isSolved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func bump(_ tile: Int) {
        bumpedTile = tile
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            bumpOffset = CGSize(width: 0, height: -6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bumpOffset = .zero }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bumpedTile = nil }
        }
    }
}

/// Fixed geometry for the Puzzle.
enum ArtPuzzle {
    static let columns = 4
    static let rows = 4
    /// Pieces the image is cut into, including the one left out as the blank.
    static let pieceCount = columns * rows

    static func makePuzzle() -> SlidingPuzzle<Int> {
        SlidingPuzzle(tileIDs: Array(0..<(pieceCount - 1)), columns: columns)
    }
}
