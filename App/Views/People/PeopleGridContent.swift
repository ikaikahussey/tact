import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// change its colour or turn it, or drag it to any cell (gaps allowed).
/// Bring Together closes the gaps. Once there are enough people to cover the
/// puzzle board, the flip button turns every tile over to the games on the
/// back (`TileGame`), and a selector picks which one is played.
struct PeopleGridContent: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(Self.showingGamesKey) private var showingGames = false
    @AppStorage(TileGame.storageKey) private var selectedGameID = TileGame.all[0].id
    @State private var openPersonID: UUID?
    @State private var dropTarget: Int?

    /// Whether the tiles are turned over. The key predates the other games.
    static let showingGamesKey = "tilesShowingPuzzle"

    /// The games are offered once there is a tile for every piece of the
    /// woodblock puzzle's board.
    static func canFlipToGames(peopleCount: Int) -> Bool {
        peopleCount >= ArtPuzzle.pieceCount
    }

    /// Room the shared round buttons take at the bottom corners, so each
    /// game can keep its own buttons clear of them.
    private static let flipButtonInset: CGFloat = 44 + 12
    private static let selectorInset: CGFloat = 140

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
        ZStack {
            tiles
            games
        }
        .background(Color.tactBackground)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 12) {
                if !showingGames && store.people.count > 1 {
                    CanvasActionButton(title: "Bring Together", systemImage: "square.grid.3x3.topleft.filled",
                                       hint: "Closes the gaps between tiles, keeping their order.",
                                       isEnabled: !TileLayout.isCompact(store.people)) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            store.bringTilesTogether()
                        }
                    }
                }
                // Always offer the way back, even if people were removed meanwhile.
                if showingGames || Self.canFlipToGames(peopleCount: store.people.count) {
                    CanvasActionButton(title: showingGames ? "Flip to Tiles" : "Flip to Games",
                                       systemImage: showingGames ? "square.grid.3x3.fill" : "puzzlepiece.fill",
                                       hint: "Turns every tile over.") {
                        showingGames.toggle()
                    }
                }
            }
            .padding(16)
        }
        .overlay(alignment: .bottomLeading) {
            if showingGames {
                gameSelector
                    .padding(16)
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showingGames)
        .overlay {
            if store.people.isEmpty && !showingGames {
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

    /// Every game, each face up only while the tiles are turned over and it
    /// is the chosen one. All stay loaded so each keeps its progress.
    private var games: some View {
        GeometryReader { geometry in
            ForEach(TileGame.all) { game in
                let isShowing = showingGames && TileGame.named(selectedGameID).id == game.id
                game.board(TileGameContext(size: geometry.size, isShowing: isShowing, flipDelay: flipDelay,
                                           leadingControlInset: Self.selectorInset,
                                           trailingControlInset: Self.flipButtonInset))
                    .allowsHitTesting(isShowing)
                    .accessibilityHidden(!isShowing)
            }
        }
    }

    /// Round icons for the games, the chosen one filled, in a capsule.
    private var gameSelector: some View {
        HStack(spacing: 4) {
            ForEach(TileGame.all) { game in
                let isSelected = TileGame.named(selectedGameID).id == game.id
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    selectedGameID = game.id
                } label: {
                    Image(systemName: game.systemImage)
                        .font(.tact(.body).weight(.semibold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactTileGray.opacity(0.5)),
                                    in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(game.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    private var tiles: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            let pitch = squareSize + spacing
            let visibleRows = Int((geometry.size.height / pitch).rounded(.up))
            let layout = TileLayout.cells(for: store.people)
            let people = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let placed = layout.compactMap { cell, id in people[id].map { (cell: cell, person: $0) } }
                .sorted { $0.cell < $1.cell }
            let cellCount = Self.cellCount(occupied: layout.keys, visibleRows: visibleRows, columns: columns)
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
                            .modifier(TileFlipFace(side: .front, showingBack: showingGames, delay: flipDelay(anchor)))
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: anchor)
                            } isTargeted: { targeted in
                                target(anchor, targeted)
                            }
                            .offset(origin(anchor))
                            .allowsHitTesting(!showingGames)
                            .accessibilityHidden(showingGames)
                    }

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
            .scrollDisabled(showingGames)
            .onChange(of: showingGames) { _, showing in
                // The games line up with the top rows.
                if showing { withAnimation { proxy.scrollTo(Self.topID, anchor: .top) } }
            }
            .onAppear {
                if showingGames { proxy.scrollTo(Self.topID, anchor: .top) }
            }
            }
        }
    }

    private static let topID = "tilesTop"

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
