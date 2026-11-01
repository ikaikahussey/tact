import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// start a note, change its color, turn it or delete the person, or drag
/// it to any cell (gaps allowed). Touch and hold an empty cell to add
/// someone there. Edit puts a delete badge on every tile; Listen makes a
/// tap play the person's ditty instead of opening them, the tile pulsing
/// while it sounds. Both are on the header's More menu, with Bring
/// Together, which closes the gaps.
/// Choosing a game turns every tile over (`TileFlipFace`) to the game on
/// the back (`GamesSurface`).
struct PeopleGridContent: View {
    let query: String
    /// Edit mode: each tile wears a delete badge instead of opening.
    var isEditing = false
    /// Listen mode: a tap plays the ditty instead of opening the person.
    var isListening = false
    /// The tiles are turned over to a game (`GamesSurface` draws the back).
    var showingGames = false
    /// Touch and hold an empty cell to add someone there.
    var onAddPerson: (_ cell: Int) -> Void = { _ in }

    @EnvironmentObject private var store: TactStore
    @State private var dropTarget: Int?
    @State private var addingNoteFor: Person?
    @State private var deleting: Person?
    /// The person whose ditty is sounding in Listen mode, for the pulse.
    @State private var sounding: UUID?
    /// How large the tiles are drawn, 1 being four across the screen.
    /// Zooming out shows more rows at once on a tall board; the controls
    /// appear once the board is past `zoomRows` rows. Games are played at
    /// full size, since their cells line up with the tiles' cells.
    @AppStorage(Self.zoomKey) private var zoom = 1.0
    static let zoomKey = "tileZoom"
    static let zoomLevels: [Double] = [1, 0.75, 0.5]
    static let zoomRows = 8

    private let columns = TileLayout.columns
    private let spacing: CGFloat = 1

    /// Cells to draw: enough rows to fill the screen, and always one empty
    /// row below the lowest tile so there is room to build downward.
    static func cellCount(occupied: some Collection<Int>, visibleRows: Int, columns: Int) -> Int {
        let lastRow = occupied.max().map { $0 / columns } ?? -1
        return max(visibleRows, lastRow + 2) * columns
    }

    private var effectiveZoom: Double { showingGames ? 1 : Self.zoomLevels.contains(zoom) ? zoom : 1 }

    /// Rows the board spans: down to the lowest tile.
    static func rows(occupied: some Collection<Int>, columns: Int) -> Int {
        occupied.max().map { $0 / columns + 1 } ?? 0
    }

    var body: some View {
        tiles
            .background(Color.tactBackground)
            .overlay(alignment: .bottomTrailing) {
                if !showingGames, Self.rows(occupied: TileLayout.cells(for: store.people).keys, columns: columns) > Self.zoomRows {
                    zoomControls
                        .padding(16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: isListening) { _, listening in
                if !listening { sounding = nil }
            }
            .sheet(item: $addingNoteFor) { person in
                AddNoteView(personID: person.id)
            }
            .alert("Delete \(deleting?.name ?? "")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) {
                    if let deleting { store.deletePerson(id: deleting.id) }
                    deleting = nil
                }
            } message: {
                Text("Notes linked only to this person are deleted too. Notes shared with other people are kept.")
            }
            .overlay {
                if store.people.isEmpty && !showingGames {
                    ContentUnavailableView {
                        Label("No People Yet", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Tap + to add someone. Each person becomes a patterned tile: tap it to open them, or touch and hold to change its color.")
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private var tiles: some View {
        GeometryReader { geometry in
            let fullSize = (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let squareSize = (fullSize * effectiveZoom).rounded(.down)
            let pitch = squareSize + spacing
            // Zoomed out, the narrower board sits in the middle.
            let inset = ((geometry.size.width - (pitch * CGFloat(columns) - spacing)) / 2).rounded(.down)
            let visibleRows = Int((geometry.size.height / pitch).rounded(.up))
            let items = PeopleGridItems(people: store.people, notes: store.notes, query: query)
            let cellCount = Self.cellCount(occupied: items.occupiedCells, visibleRows: visibleRows, columns: columns)
            let origin = { (cell: Int) in
                CGSize(width: inset + CGFloat(cell % columns) * pitch, height: CGFloat(cell / columns) * pitch)
            }

            ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<cellCount, id: \.self) { cell in
                        Color.tactTileGray.opacity(0.35)
                            .frame(width: squareSize, height: squareSize)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.4) {
                                guard !showingGames, !isEditing else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onAddPerson(cell)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: cell)
                            } isTargeted: { targeted in
                                target(cell, targeted)
                            }
                            .offset(origin(cell))
                            .accessibilityHidden(true)
                    }

                    ForEach(items.tiles, id: \.person.id) { placed in
                        tile(for: placed.person, size: squareSize)
                            .anchorPreference(key: TileAnchors.self, value: .bounds) { [placed.person.id: $0] }
                            .modifier(TileFlipFace(side: .front, showingBack: showingGames,
                                                   delay: TileFlipFace.delay(forCell: placed.cell, columns: columns)))
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: placed.cell)
                            } isTargeted: { targeted in
                                target(placed.cell, targeted)
                            }
                            .offset(origin(placed.cell))
                            .allowsHitTesting(!showingGames)
                            .accessibilityHidden(showingGames)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
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
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items)
                .animation(.snappy, value: isEditing)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: effectiveZoom)
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

    // MARK: Zoom

    /// Two buttons in a capsule: in and out, a level at a time.
    private var zoomControls: some View {
        let index = Self.zoomLevels.firstIndex(of: effectiveZoom) ?? 0
        return VStack(spacing: 0) {
            zoomButton("Zoom In", systemImage: "plus.magnifyingglass", isEnabled: index > 0) {
                zoom = Self.zoomLevels[index - 1]
            }
            Divider().frame(width: 24)
            zoomButton("Zoom Out", systemImage: "minus.magnifyingglass", isEnabled: index < Self.zoomLevels.count - 1) {
                zoom = Self.zoomLevels[index + 1]
            }
        }
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom")
    }

    private func zoomButton(_ title: String, systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.tact(.body).weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        store.moveTile(personID: id, toCell: cell)
        return true
    }

    private func target(_ cell: Int, _ targeted: Bool) {
        if targeted { dropTarget = cell } else if dropTarget == cell { dropTarget = nil }
    }

    /// Listen mode's tap: the ditty, with the tile pressed while it sounds.
    private func listen(to person: Person) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sounding = person.id
        DittyPlayer.play(person) { index in
            if index == nil, sounding == person.id { sounding = nil }
        }
    }

    private func tile(for person: Person, size: CGFloat) -> some View {
        let colorIndex = Binding(
            get: { person.tile.colorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.colorIndex = newValue }
            }
        )
        return Group {
            if isListening {
                Button { listen(to: person) } label: {
                    PersonTile(person: person, size: size)
                        .contentShape(Rectangle())
                }
            } else {
                NavigationLink(value: Route.person(person.id)) {
                    PersonTile(person: person, size: size)
                        .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isEditing)
        .scaleEffect(sounding == person.id ? 0.92 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: sounding == person.id)
        .overlay(alignment: .topLeading) {
            if isEditing {
                Button { deleting = person } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.tact(.title2))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(person.name)")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contextMenu {
            Button { addingNoteFor = person } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            Button { DittyPlayer.play(person) } label: {
                Label("Play Ditty", systemImage: "music.note")
            }
            Divider()
            Menu {
                // Just the colours, no names; VoiceOver still gets them.
                Picker("Color", selection: colorIndex) {
                    ForEach(TilePalette.menuOrder, id: \.self) { index in
                        Image(uiImage: TilePalette.swatch(index))
                            .accessibilityLabel(TilePalette.name(index).capitalized)
                            .tag(index)
                    }
                }
            } label: {
                Label("Color", systemImage: "paintpalette")
            }
            Button { store.updateTile(forPersonID: person.id) { $0.rotate() } } label: {
                Label("Rotate", systemImage: "rotate.right")
            }
            Divider()
            Button(role: .destructive) { deleting = person } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .draggable(person.id.uuidString) {
            PersonTile(person: person, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile")
        .accessibilityHint(isListening ? "Plays \(person.name)'s ditty."
                           : "Opens \(person.name). Touch and hold for a new note, the ditty, the color, turning, or deleting; drag to move it.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Change color") {
            let order = TilePalette.menuOrder
            let next = order[((order.firstIndex(of: person.tile.colorIndex) ?? 0) + 1) % order.count]
            store.updateTile(forPersonID: person.id) { $0.colorIndex = next }
        }
        .accessibilityAction(named: "Rotate") {
            store.updateTile(forPersonID: person.id) { $0.rotate() }
        }
        .accessibilityAction(named: "Play ditty") { DittyPlayer.play(person) }
        .accessibilityAction(named: "New note") { addingNoteFor = person }
        .accessibilityAction(named: "Delete") { deleting = person }
    }
}
