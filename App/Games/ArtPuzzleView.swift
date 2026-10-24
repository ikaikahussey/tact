import SwiftUI

/// A sliding puzzle: the photo is cut into a 4×4 grid with one piece missing,
/// scrambled, and restored by dragging pieces into the empty space. Dragging a
/// piece that cannot move gives a small bump instead.
struct ArtPuzzleView: View {
    @EnvironmentObject private var store: TactStore
    @State private var puzzle = ArtPuzzle.makePuzzle()
    @State private var moveCount = 0
    @State private var hasStarted = false
    @State private var showingSettings = false

    // Drag state. Offsets apply to `draggedTiles` along one axis.
    @State private var draggedTiles: Set<Int> = []
    @State private var dragHorizontal = true
    @State private var dragSign: CGFloat = 1
    @State private var dragAmount: CGFloat = 0
    @State private var bumpedTile: Int?
    @State private var bumpOffset: CGSize = .zero

    private let columns = ArtPuzzle.columns
    private let commitAnimation = Animation.spring(response: 0.32, dampingFraction: 0.78)

    private var imageData: Data { store.puzzleImageData }
    private var isSolved: Bool { hasStarted && puzzle.isSolved }
    private var movesText: String { moveCount == 1 ? "1 move" : "\(moveCount) moves" }

    var body: some View {
        GeometryReader { geometry in
            let boardSize = min(geometry.size.width, geometry.size.height - 90) - 32
            let step = (boardSize / CGFloat(columns)).rounded(.down)
            ScrollView {
                VStack(spacing: 16) {
                    board(step: step)
                        .frame(width: step * CGFloat(columns), height: step * CGFloat(columns))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .padding(.top, 8)
                    controls
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
        }
        .background(Color.tactBackground)
        .onAppear { if !hasStarted { newGame(animated: false) } }
        .onChange(of: store.settings.artSettings.imageData) { _, _ in newGame(animated: true) }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                ArtSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: Board

    private func board(step: CGFloat) -> some View {
        ZStack {
            Color.tactTileGray
            ForEach(puzzle.tiles, id: \.self) { tile in
                if let slot = puzzle.slot(of: tile) {
                    pieceView(tile: tile, step: step)
                        .frame(width: step - 2, height: step - 2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .position(center(of: slot, step: step))
                        .offset(offset(for: tile, step: step))
                        .zIndex(draggedTiles.contains(tile) || bumpedTile == tile ? 1 : 0)
                        .gesture(dragGesture(for: tile, step: step))
                        .onTapGesture { tapped(tile) }
                        .accessibilityLabel("Piece \(tile + 1)")
                        .accessibilityHint("Drag or double-tap to slide toward the empty space")
                }
            }
            if isSolved, let missing = ArtImageCache.shared.tile(for: imageData, index: puzzle.tiles.count, tileCount: ArtPuzzle.pieceCount) {
                // Fill the empty space so the finished picture is whole.
                Image(uiImage: missing)
                    .resizable()
                    .scaledToFill()
                    .frame(width: step - 2, height: step - 2)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(center(of: puzzle.blankIndex, step: step))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(commitAnimation, value: isSolved)
    }

    @ViewBuilder
    private func pieceView(tile: Int, step: CGFloat) -> some View {
        if let image = ArtImageCache.shared.tile(for: imageData, index: tile, tileCount: ArtPuzzle.pieceCount) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.tactCardBackground
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                if isSolved {
                    Label("Solved in \(movesText)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                } else {
                    Text(movesText)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("New Game", systemImage: "shuffle") { newGame(animated: true) }
                    .buttonStyle(.bordered)
                Button("Photo", systemImage: "photo") { showingSettings = true }
                    .buttonStyle(.bordered)
            }
            if !hasStarted || isSolved {
                Text("Drag the pieces into the empty space to rebuild the picture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: isSolved)
    }

    // MARK: Geometry

    private func center(of slot: Int, step: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(slot % columns) + 0.5) * step,
                y: (CGFloat(slot / columns) + 0.5) * step)
    }

    private func offset(for tile: Int, step: CGFloat) -> CGSize {
        if bumpedTile == tile { return bumpOffset }
        guard draggedTiles.contains(tile) else { return .zero }
        let distance = dragAmount * dragSign
        return dragHorizontal ? CGSize(width: distance, height: 0) : CGSize(width: 0, height: distance)
    }

    // MARK: Interaction

    private func dragGesture(for tile: Int, step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if draggedTiles.isEmpty && bumpedTile == nil {
                    beginDrag(tile: tile)
                }
                if draggedTiles.contains(tile) {
                    let raw = dragHorizontal ? value.translation.width : value.translation.height
                    dragAmount = min(step, max(0, raw * dragSign))
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
                    if dragAmount > step * 0.4 || predicted > step * 0.6 {
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
        guard !isSolved, let slot = puzzle.slot(of: tile) else { return }
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
        guard !isSolved, let slot = puzzle.slot(of: tile) else { return }
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
            if puzzle.tap(slot) { moveCount += 1 }
            dragAmount = 0
        }
        draggedTiles = []
        if puzzle.isSolved {
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

    private func newGame(animated: Bool) {
        draggedTiles = []
        dragAmount = 0
        bumpedTile = nil
        var fresh = ArtPuzzle.makePuzzle()
        fresh.shuffle()
        moveCount = 0
        hasStarted = true
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { puzzle = fresh }
        } else {
            puzzle = fresh
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
