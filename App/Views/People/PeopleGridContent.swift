import SwiftUI

/// What the Tiles grid is doing.
enum GridMode {
    /// Tap a tile to open the person; touch and hold to start reordering.
    case browse
    /// Tiles jiggle and can be dragged into a new order.
    case reorder
    /// The tiles on screen are scrambled into a sliding puzzle.
    case puzzle
}

/// Four-column grid of people. Long-press enters "jiggle" mode, where tiles
/// can be dragged to reorder them. Once people fill the screen, the visible
/// tiles can be shuffled into a sliding puzzle played in place.
struct PeopleGridContent: View {
    @EnvironmentObject private var store: TactStore
    let tileStyle: TileStyle
    @Binding var mode: GridMode
    /// A game picked from the People menu, started (or explained) on arrival.
    @Binding var pendingGame: Game?
    /// How many more people are needed before the puzzle unlocks.
    @Binding var unlockShortfall: Int?
    let addPerson: () -> Void

    @State private var draggedID: UUID?
    @State private var dragAnchorIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingActive = false

    @State private var puzzle = SlidingPuzzle<UUID>(tileIDs: [])
    @State private var moveCount = 0
    @State private var isSolved = false
    @State private var isCelebrating = false
    @State private var openPersonID: UUID?
    @AppStorage("hasSeenPuzzleHint") private var hasSeenPuzzleHint = false

    private let columns = 4
    private let spacing: CGFloat = 1
    /// Room kept free at the bottom for the puzzle controls.
    private let controlsHeight: CGFloat = 64
    private let reorderAnimation = Animation.interpolatingSpring(stiffness: 200, damping: 22)
    private static let topID = "grid-top"
    private static let unlockID = "grid-unlock"

    /// People on the puzzle board when the grid area is `height` points tall:
    /// every full row that fits, minus one slot for the blank (where the "+"
    /// tile sits in the grid).
    static func boardCount(height: CGFloat, squareSize: CGFloat, spacing: CGFloat, columns: Int) -> Int {
        guard squareSize > 0, height > 0 else { return 0 }
        let rowsThatFit = Int(height / (squareSize + spacing))
        return max(0, rowsThatFit * columns - 1)
    }

    /// A solved puzzle of the first `boardCount` people, in list order.
    static func makePuzzle(people: [Person], boardCount: Int, columns: Int) -> SlidingPuzzle<UUID> {
        SlidingPuzzle(tileIDs: people.prefix(boardCount).map(\.id), columns: columns)
    }

    var body: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            let boardCount = Self.boardCount(height: geometry.size.height - controlsHeight,
                                             squareSize: squareSize, spacing: spacing, columns: columns)
            let isUnlocked = boardCount >= 3 && store.people.count >= boardCount
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: spacing) {
                        Color.clear.frame(height: 0).id(Self.topID)
                        if mode == .puzzle {
                            puzzleBoard(squareSize: squareSize)
                            grid(people: Array(store.people.dropFirst(puzzle.tiles.count)), squareSize: squareSize, showsAdd: false)
                                .opacity(0.35)
                                .allowsHitTesting(false)
                        } else {
                            grid(people: store.people, squareSize: squareSize, showsAdd: true)
                            if !isUnlocked && boardCount >= 3 && mode == .browse {
                                unlockFooter(shortfall: boardCount - store.people.count)
                                    .id(Self.unlockID)
                            }
                        }
                    }
                    .padding(.bottom, controlsHeight)
                }
                .scrollDisabled(isDraggingActive || mode == .puzzle)
                .overlay(alignment: .bottom) {
                    controls(isUnlocked: isUnlocked) { startPuzzle(boardCount: boardCount, proxy: proxy) }
                }
                .onChange(of: isUnlocked ? 0 : max(0, boardCount - store.people.count), initial: true) { _, shortfall in
                    unlockShortfall = boardCount >= 3 ? shortfall : nil
                }
                .onChange(of: pendingGame, initial: true) { _, game in
                    guard game == .artPuzzle else { return }
                    pendingGame = nil
                    // Let the grid lay out (it may have just appeared) before acting.
                    DispatchQueue.main.async {
                        if isUnlocked {
                            if mode != .puzzle { startPuzzle(boardCount: boardCount, proxy: proxy) }
                        } else {
                            withAnimation { proxy.scrollTo(Self.unlockID, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(Color.tactBackground)
        .navigationDestination(item: $openPersonID) { id in
            PersonDetailView(personID: id)
        }
        .onChange(of: mode) { oldMode, newMode in
            if oldMode == .reorder { finalizeReorder() }
            if newMode != .puzzle { isSolved = false }
        }
        .onChange(of: store.people.map(\.id)) { _, _ in
            // Someone was added, removed or moved: the board no longer matches.
            if mode == .puzzle { withAnimation { mode = .browse } }
        }
    }

    // MARK: Grid

    private func grid(people: [Person], squareSize: CGFloat, showsAdd: Bool) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(people) { person in
                PersonSquare(
                    person: person,
                    tileStyle: tileStyle,
                    squareSize: squareSize,
                    isJiggleMode: Binding(get: { mode == .reorder },
                                          set: { mode = $0 ? .reorder : .browse }),
                    isDragging: draggedID == person.id,
                    dragOffset: dragOffset,
                    onDragChanged: { translation in
                        dragChanged(person: person, translation: translation, step: squareSize + spacing)
                    },
                    onDragEnded: finalizeReorder
                )
            }
            if showsAdd {
                Button(action: addPerson) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .foregroundStyle(.primary)
                        .frame(width: squareSize, height: squareSize)
                        .background(Color.tactTileGray)
                        .opacity(isDraggingActive ? 0.3 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isDraggingActive)
                .accessibilityLabel("Add Person")
            }
        }
    }

    private func unlockFooter(shortfall: Int) -> some View {
        Label(shortfall == 1 ? "Add 1 more person to unlock the puzzle"
                             : "Add \(shortfall) more people to unlock the puzzle",
              systemImage: "puzzlepiece")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }

    // MARK: Puzzle

    private func puzzleBoard(squareSize: CGFloat) -> some View {
        let step = squareSize + spacing
        let order = Dictionary(uniqueKeysWithValues: puzzle.solvedOrder.enumerated().map { ($1, $0) })
        let people = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let blank = puzzle.blankIndex
        let blankCenter = CGPoint(x: CGFloat(blank % columns) * step + squareSize / 2,
                                  y: CGFloat(blank / columns) * step + squareSize / 2)
        return ZStack(alignment: .topLeading) {
            Color.tactTileGray
                .frame(width: squareSize, height: squareSize)
                .position(blankCenter)
            if isSolved {
                ZStack {
                    Color.accentColor
                    Image(systemName: "sparkles")
                        .font(.system(size: squareSize * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: squareSize, height: squareSize)
                .position(blankCenter)
                .transition(.opacity.combined(with: .scale))
                .accessibilityHidden(true)
            }
            SlidingPuzzleBoard(
                puzzle: $puzzle,
                step: step,
                spacing: spacing,
                isInteractive: !isSolved,
                onMove: puzzleMoved,
                onLongPress: { openPersonID = $0 }
            ) { id in
                if let person = people[id] {
                    PersonTile(person: person, style: tileStyle, size: squareSize)
                        .scaleEffect(isCelebrating ? 1.06 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5)
                                    .delay(Double(order[id] ?? 0) * 0.03),
                                   value: isCelebrating)
                }
            }
        }
        .frame(width: step * CGFloat(columns) - spacing,
               height: step * CGFloat(puzzle.rows) - spacing,
               alignment: .topLeading)
    }

    @ViewBuilder
    private func controls(isUnlocked: Bool, start: @escaping () -> Void) -> some View {
        switch mode {
        case .puzzle:
            VStack(spacing: 8) {
                if !hasSeenPuzzleHint && !isSolved {
                    Text("Slide the tiles to put everyone back in order. Touch and hold a tile to open that person.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .transition(.opacity)
                }
                HStack(spacing: 12) {
                    if isSolved {
                        Label(moveCount == 1 ? "Solved in 1 move" : "Solved in \(moveCount) moves",
                              systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    } else {
                        Text(moveCount == 1 ? "1 move" : "\(moveCount) moves")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Shuffle", systemImage: "shuffle", action: reshuffle)
                        .disabled(isSolved)
                    Button("Quit", action: quitPuzzle)
                        .fontWeight(.semibold)
                        .disabled(isSolved)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: isSolved)
            .animation(.easeInOut(duration: 0.2), value: hasSeenPuzzleHint)
        case .browse where isUnlocked:
            HStack {
                Spacer()
                Button(action: start) {
                    Label("Shuffle", systemImage: "shuffle")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Scrambles the tiles into a sliding puzzle")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        default:
            EmptyView()
        }
    }

    /// Swaps the grid for a solved board in the same place, then scatters it.
    private func startPuzzle(boardCount: Int, proxy: ScrollViewProxy) {
        guard boardCount >= 3, store.people.count >= boardCount else { return }
        proxy.scrollTo(Self.topID, anchor: .top)
        puzzle = Self.makePuzzle(people: store.people, boardCount: boardCount, columns: columns)
        moveCount = 0
        isSolved = false
        mode = .puzzle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard mode == .puzzle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { puzzle.shuffle() }
        }
    }

    private func reshuffle() {
        moveCount = 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { puzzle.shuffle() }
    }

    /// Slides everyone home, then hands back to the grid.
    private func quitPuzzle() {
        hasSeenPuzzleHint = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            puzzle = SlidingPuzzle(tileIDs: puzzle.solvedOrder, columns: columns)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if mode == .puzzle { mode = .browse }
        }
    }

    private func puzzleMoved() {
        moveCount += 1
        hasSeenPuzzleHint = true
        guard puzzle.isSolved else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isSolved = true }
        isCelebrating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isCelebrating = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // The tiles are already in grid order, so the swap back is seamless.
            if mode == .puzzle && isSolved { mode = .browse }
        }
    }

    // MARK: Reordering

    private func dragChanged(person: Person, translation: CGSize, step: CGFloat) {
        if draggedID == nil {
            dragAnchorIndex = store.people.firstIndex { $0.id == person.id }
            withAnimation(reorderAnimation) {
                draggedID = person.id
                isDraggingActive = true
            }
        }
        guard draggedID == person.id,
              let anchor = dragAnchorIndex,
              let currentIndex = store.people.firstIndex(where: { $0.id == person.id })
        else { return }

        // Which slot the tile is hovering over, measured from where the drag started.
        let columnOffset = Int((translation.width / step).rounded())
        let rowOffset = Int((translation.height / step).rounded())
        let targetColumn = min(columns - 1, max(0, anchor % columns + columnOffset))
        let targetRow = max(0, anchor / columns + rowOffset)
        let target = min(store.people.count - 1, targetRow * columns + targetColumn)

        // The tile is drawn at its new slot plus an offset, so the offset has to
        // subtract the distance the slot itself moved.
        let compensated = CGSize(
            width: translation.width - CGFloat(target % columns - anchor % columns) * step,
            height: translation.height - CGFloat(target / columns - anchor / columns) * step
        )
        if target != currentIndex {
            withAnimation(reorderAnimation) {
                store.movePeople(fromOffsets: IndexSet(integer: currentIndex),
                                 toOffset: target > currentIndex ? target + 1 : target)
                dragOffset = compensated
            }
        } else {
            dragOffset = compensated
        }
    }

    private func finalizeReorder() {
        guard draggedID != nil else { return }
        withAnimation(reorderAnimation) {
            dragOffset = .zero
            isDraggingActive = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            draggedID = nil
            dragAnchorIndex = nil
        }
    }
}

/// One tile in the grid, with the jiggle animation and drag gesture.
struct PersonSquare: View {
    let person: Person
    let tileStyle: TileStyle
    let squareSize: CGFloat
    @Binding var isJiggleMode: Bool
    let isDragging: Bool
    let dragOffset: CGSize
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    @State private var jiggleAngle: Double = 0

    var body: some View {
        Group {
            if isJiggleMode {
                PersonTile(person: person, style: tileStyle, size: squareSize)
            } else {
                NavigationLink {
                    PersonDetailView(personID: person.id)
                } label: {
                    PersonTile(person: person, style: tileStyle, size: squareSize)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: squareSize, height: squareSize)
        .offset(isDragging ? dragOffset : .zero)
        .rotationEffect(.degrees(isJiggleMode && !isDragging ? jiggleAngle : 0))
        .scaleEffect(isJiggleMode && !isDragging ? 0.92 : (isDragging ? 1.08 : 1))
        .opacity(isDragging ? 0.9 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: isDragging ? 10 : 0, y: isDragging ? 4 : 0)
        .zIndex(isDragging ? 100 : 0)
        .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: isDragging)
        .animation(.easeInOut(duration: 0.12), value: isJiggleMode)
        .onAppear { if isJiggleMode { startJiggling() } }
        .onChange(of: isJiggleMode) { _, enabled in
            if enabled {
                startJiggling()
            } else {
                withAnimation(.easeInOut(duration: 0.12)) { jiggleAngle = 0 }
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !isJiggleMode else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { isJiggleMode = true }
            }
        )
        .gesture(
            DragGesture(minimumDistance: isJiggleMode ? 5 : 1000)
                .onChanged { value in
                    if isJiggleMode { onDragChanged(value.translation) }
                }
                .onEnded { _ in
                    if isJiggleMode && isDragging { onDragEnded() }
                }
        )
        .accessibilityHint(isJiggleMode ? "Drag to reorder" : "Double-tap to open. Touch and hold to reorder.")
    }

    private func startJiggling() {
        let delay = Double.random(in: 0...0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isJiggleMode else { return }
            withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                jiggleAngle = 2.5
            }
        }
    }
}
