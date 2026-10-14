import SwiftUI

/// Draws a sliding puzzle and handles its gestures: drag a tile (or the run of
/// tiles behind it) into the blank, tap to slide, and a small bump for tiles
/// that cannot move. Touch and hold a tile to call `onLongPress`.
///
/// Slots are laid out row-major from the top-left, `step` apart, with each tile
/// `step - spacing` wide, so a solved board lines up exactly with a
/// `LazyVGrid` using the same square size and spacing.
struct SlidingPuzzleBoard<Tile: Hashable, Content: View>: View {
    @Binding var puzzle: SlidingPuzzle<Tile>
    let step: CGFloat
    let spacing: CGFloat
    var isInteractive = true
    var onMove: () -> Void = {}
    var onLongPress: (Tile) -> Void = { _ in }
    @ViewBuilder let content: (Tile) -> Content

    // Drag state. Offsets apply to `draggedTiles` along one axis.
    @State private var draggedTiles: Set<Tile> = []
    @State private var dragHorizontal = true
    @State private var dragSign: CGFloat = 1
    @State private var dragAmount: CGFloat = 0
    @State private var bumpedTile: Tile?
    @State private var bumpOffset: CGSize = .zero
    @State private var pressedTile: Tile?

    private let commitAnimation = Animation.spring(response: 0.32, dampingFraction: 0.78)

    private var columns: Int { puzzle.columns }
    private var tileSize: CGFloat { step - spacing }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(puzzle.tiles, id: \.self) { tile in
                if let slot = puzzle.slot(of: tile) {
                    content(tile)
                        .frame(width: tileSize, height: tileSize)
                        .scaleEffect(pressedTile == tile ? 1.06 : 1)
                        .animation(.easeOut(duration: 0.15), value: pressedTile == tile)
                        .position(center(of: slot))
                        .offset(offset(for: tile))
                        .zIndex(draggedTiles.contains(tile) || bumpedTile == tile || pressedTile == tile ? 1 : 0)
                        .gesture(dragGesture(for: tile))
                        .onTapGesture { tapped(tile) }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            longPressed(tile)
                        } onPressingChanged: { pressing in
                            if pressing && isInteractive && draggedTiles.isEmpty {
                                pressedTile = tile
                            } else if pressedTile == tile {
                                pressedTile = nil
                            }
                        }
                        .accessibilityHint("Drag or double-tap to slide toward the empty space")
                        .accessibilityAction(named: "Open person") { onLongPress(tile) }
                }
            }
        }
        .frame(width: step * CGFloat(columns) - spacing,
               height: step * CGFloat(puzzle.rows) - spacing,
               alignment: .topLeading)
    }

    // MARK: Geometry

    func center(of slot: Int) -> CGPoint {
        CGPoint(x: CGFloat(slot % columns) * step + tileSize / 2,
                y: CGFloat(slot / columns) * step + tileSize / 2)
    }

    private func offset(for tile: Tile) -> CGSize {
        if bumpedTile == tile { return bumpOffset }
        guard draggedTiles.contains(tile) else { return .zero }
        let distance = dragAmount * dragSign
        return dragHorizontal ? CGSize(width: distance, height: 0) : CGSize(width: 0, height: distance)
    }

    // MARK: Interaction

    /// Holding still on a tile opens it. Moving or lifting early cancels the
    /// press, so drags and taps still slide tiles.
    private func longPressed(_ tile: Tile) {
        pressedTile = nil
        guard isInteractive, draggedTiles.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onLongPress(tile)
    }

    private func dragGesture(for tile: Tile) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                pressedTile = nil
                if draggedTiles.isEmpty && bumpedTile == nil {
                    beginDrag(tile: tile)
                }
                if draggedTiles.contains(tile) {
                    let raw = dragHorizontal ? value.translation.width : value.translation.height
                    dragAmount = min(step, max(0, raw * dragSign))
                } else if bumpedTile == tile {
                    // Resist: the tile nudges a few points and no more.
                    let resistance: CGFloat = 0.18, limit: CGFloat = 10
                    bumpOffset = CGSize(width: max(-limit, min(limit, value.translation.width * resistance)),
                                        height: max(-limit, min(limit, value.translation.height * resistance)))
                }
            }
            .onEnded { value in
                if draggedTiles.contains(tile) {
                    let raw = dragHorizontal ? value.predictedEndTranslation.width : value.predictedEndTranslation.height
                    let predicted = raw * dragSign
                    if dragAmount > step * 0.4 || predicted > step * 0.6 {
                        commitMove(from: tile)
                    } else {
                        withAnimation(commitAnimation) { dragAmount = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if dragAmount == 0 { draggedTiles = [] }
                        }
                    }
                } else if bumpedTile == tile {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bumpOffset = .zero }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if bumpOffset == .zero { bumpedTile = nil }
                    }
                }
            }
    }

    private func beginDrag(tile: Tile) {
        guard isInteractive, let slot = puzzle.slot(of: tile) else { return }
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

    private func tapped(_ tile: Tile) {
        guard isInteractive, let slot = puzzle.slot(of: tile) else { return }
        if puzzle.moveDirection(from: slot) != nil {
            draggedTiles = Set(puzzle.run(from: slot).compactMap { puzzle.slots[$0] })
            dragAmount = 0
            commitMove(from: tile)
        } else {
            bump(tile)
        }
    }

    /// Slides the run into the blank. The slot change and the drag offset are
    /// animated together so the tiles finish their motion without jumping.
    private func commitMove(from tile: Tile) {
        guard let slot = puzzle.slot(of: tile) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var moved = false
        withAnimation(commitAnimation) {
            moved = puzzle.tap(slot)
            dragAmount = 0
        }
        draggedTiles = []
        if moved { onMove() }
    }

    private func bump(_ tile: Tile) {
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
