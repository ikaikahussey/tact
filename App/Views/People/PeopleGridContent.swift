import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// change its colour or turn it, or drag it to any cell (gaps allowed).
/// Bring Together closes the gaps. Once there are enough people to cover the
/// puzzle board, the flip button turns every tile over to show the picture
/// puzzle on the back of the top four rows.
struct PeopleGridContent: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(Self.showingPuzzleKey) private var showingPuzzle = false
    @State private var game = PuzzleGame()
    @State private var openPersonID: UUID?
    @State private var dropTarget: Int?
    @State private var showingPuzzleSettings = false

    static let showingPuzzleKey = "tilesShowingPuzzle"

    /// The puzzle is offered once there is a tile for every piece of the board.
    static func canFlipToPuzzle(peopleCount: Int) -> Bool {
        peopleCount >= ArtPuzzle.pieceCount
    }

    private let columns = TileLayout.columns
    private let spacing: CGFloat = 1

    /// Cells to draw: enough rows to fill the screen, and always one empty
    /// row below the lowest tile so there is room to build downward.
    static func cellCount(occupied: some Collection<Int>, visibleRows: Int, columns: Int) -> Int {
        let lastRow = occupied.max().map { $0 / columns } ?? -1
        return max(visibleRows, lastRow + 2) * columns
    }

    private func flipDelay(_ cell: Int) -> Double {
        TileFlipFace.delay(forCell: cell, columns: columns)
    }

    var body: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            let pitch = squareSize + spacing
            let visibleRows = Int((geometry.size.height / pitch).rounded(.up))
            let layout = TileLayout.cells(for: store.people)
            let people = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let placed = layout.compactMap { cell, id in people[id].map { (cell: cell, person: $0) } }
                .sorted { $0.cell < $1.cell }
            // Leave room under the puzzle for its status line.
            let cellCount = Self.cellCount(occupied: layout.keys, visibleRows: max(visibleRows, ArtPuzzle.rows + 1), columns: columns)
            let origin = { (cell: Int) in
                CGSize(width: CGFloat(cell % columns) * pitch, height: CGFloat(cell / columns) * pitch)
            }

            ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<cellCount, id: \.self) { cell in
                        Color.tactTileGray.opacity(0.35)
                            .frame(width: squareSize, height: squareSize)
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: cell)
                            } isTargeted: { targeted in
                                target(cell, targeted)
                            }
                            .offset(origin(cell))
                            .accessibilityHidden(true)
                    }

                    ForEach(placed, id: \.person.id) { anchor, person in
                        tile(for: person, size: squareSize)
                            .modifier(TileFlipFace(side: .front, showingBack: showingPuzzle, delay: flipDelay(anchor)))
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: anchor)
                            } isTargeted: { targeted in
                                target(anchor, targeted)
                            }
                            .offset(origin(anchor))
                            .allowsHitTesting(!showingPuzzle)
                            .accessibilityHidden(showingPuzzle)
                    }

                    PuzzleBoard(game: game, pitch: pitch, pieceSize: squareSize,
                                isShowing: showingPuzzle, flipDelay: flipDelay)

                    puzzleStatus
                        .frame(width: geometry.size.width - 32, alignment: .leading)
                        .offset(x: 16, y: CGFloat(ArtPuzzle.rows) * pitch + 12)
                        .opacity(showingPuzzle ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2).delay(showingPuzzle ? 0.35 : 0), value: showingPuzzle)
                        .accessibilityHidden(!showingPuzzle)

                    if let dropTarget {
                        Rectangle()
                            .strokeBorder(.tint, lineWidth: 3)
                            .frame(width: squareSize, height: squareSize)
                            .offset(origin(dropTarget))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: CGFloat(cellCount / columns) * pitch, alignment: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: layout)
                .padding(.bottom, 80)
                .id(Self.topID)
            }
            .scrollDisabled(showingPuzzle)
            .onChange(of: showingPuzzle) { _, showing in
                // The puzzle is on the back of the top rows.
                if showing { withAnimation { proxy.scrollTo(Self.topID, anchor: .top) } }
            }
            .onAppear {
                if showingPuzzle { proxy.scrollTo(Self.topID, anchor: .top) }
            }
            }
        }
        .background(Color.tactBackground)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 12) {
                if showingPuzzle {
                    CanvasActionButton(title: "Choose Photo", systemImage: "photo",
                                       hint: "Picks the picture for the puzzle.") {
                        showingPuzzleSettings = true
                    }
                    CanvasActionButton(title: "New Game", systemImage: "shuffle",
                                       hint: "Scrambles the puzzle and starts again.") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { game.newGame() }
                    }
                } else if store.people.count > 1 {
                    CanvasActionButton(title: "Bring Together", systemImage: "square.grid.3x3.topleft.filled",
                                       hint: "Closes the gaps between tiles, keeping their order.",
                                       isEnabled: !TileLayout.isCompact(store.people)) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            store.bringTilesTogether()
                        }
                    }
                }
                // Always offer the way back, even if people were removed meanwhile.
                if showingPuzzle || Self.canFlipToPuzzle(peopleCount: store.people.count) {
                    CanvasActionButton(title: showingPuzzle ? "Flip to Tiles" : "Flip to Puzzle",
                                       systemImage: showingPuzzle ? "square.grid.3x3.fill" : "puzzlepiece.fill",
                                       hint: "Turns every tile over.") {
                        showingPuzzle.toggle()
                    }
                }
            }
            .padding(16)
        }
        .onChange(of: store.settings.artSettings.imageData) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { game.newGame() }
        }
        .sheet(isPresented: $showingPuzzleSettings) {
            NavigationStack {
                ArtSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPuzzleSettings = false }
                        }
                    }
            }
        }
        .overlay {
            if store.people.isEmpty && !showingPuzzle {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "square.grid.2x2")
                } description: {
                    Text("Tap + to add someone. Each person becomes a patterned tile: tap it to open them, or touch and hold to change its colour.")
                }
            }
        }
        .navigationDestination(item: $openPersonID) { id in
            PersonDetailView(personID: id)
        }
    }

    private static let topID = "tilesTop"

    private var puzzleStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            if game.isSolved {
                Label("Solved in \(game.movesText)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
            } else {
                Text(game.movesText)
                    .foregroundStyle(.secondary)
            }
            if game.moveCount == 0 || game.isSolved {
                Text("Drag the pieces into the empty space to rebuild the picture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.isSolved)
    }

    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        store.moveTile(personID: id, toCell: cell)
        return true
    }

    private func target(_ cell: Int, _ targeted: Bool) {
        if targeted { dropTarget = cell } else if dropTarget == cell { dropTarget = nil }
    }

    private func tile(for person: Person, size: CGFloat) -> some View {
        let colorIndex = Binding(
            get: { person.tile.colorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.colorIndex = newValue }
            }
        )
        return PersonTile(person: person, size: size)
            .contentShape(Rectangle())
            .onTapGesture { openPersonID = person.id }
            .contextMenu {
                Menu {
                    Picker("Color", selection: colorIndex) {
                        ForEach(TilePalette.menuOrder, id: \.self) { index in
                            Label {
                                Text(TilePalette.name(index).capitalized)
                            } icon: {
                                Image(uiImage: TilePalette.swatch(index))
                            }
                            .tag(index)
                        }
                    }
                } label: {
                    Label("Color", systemImage: "paintpalette")
                }
                Button { store.updateTile(forPersonID: person.id) { $0.rotate() } } label: {
                    Label("Rotate", systemImage: "rotate.right")
                }
            }
            .draggable(person.id.uuidString) {
                PersonTile(person: person, size: size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile")
            .accessibilityHint("Opens \(person.name). Touch and hold to change the colour, turn the tile, or move it.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Change colour") {
                let order = TilePalette.menuOrder
                let next = order[((order.firstIndex(of: person.tile.colorIndex) ?? 0) + 1) % order.count]
                store.updateTile(forPersonID: person.id) { $0.colorIndex = next }
            }
            .accessibilityAction(named: "Rotate") {
                store.updateTile(forPersonID: person.id) { $0.rotate() }
            }
    }
}
