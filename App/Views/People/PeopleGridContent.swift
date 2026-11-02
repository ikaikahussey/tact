import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// start a note, change its color, turn it or delete the person, or drag
/// it to any cell (gaps allowed). Touch and hold an empty cell to add
/// someone there. Edit puts a delete badge on every tile, and a tap then
/// selects a tile (a check at its corner); dragging any selected tile
/// moves the whole selection together, keeping its shape. Listen makes a
/// tap play the person's ditty instead of opening them, the tile pulsing
/// while it sounds; Select makes a tap gather tiles, marked with a check,
/// for the bar below to change together, and they too drag as one. All
/// are on the header's More menu, with Bring Together, which closes the
/// gaps.
/// Choosing a game turns the tiles over (`TileFlipFace`) to the game on
/// the back (`GamesSurface`); only the tiles turn, so the game's pieces
/// are the tiles. A game short of tiles leaves them face up under its
/// notice.
struct PeopleGridContent: View {
    let query: String
    /// Edit mode: each tile wears a delete badge instead of opening.
    var isEditing = false
    /// Listen mode: a tap plays the ditty instead of opening the person.
    var isListening = false
    /// Select mode: a tap adds the tile to `selection` or takes it out.
    var isSelecting = false
    @Binding var selection: Set<UUID>
    /// The canvas shows a game (`GamesSurface` draws the back): the tiles
    /// are locked and the view sits at the top.
    var showingGames = false
    /// Whether the tiles turn over while a game shows; false when the game
    /// has too few tiles to play and shows a notice instead.
    var tilesTurned = true
    /// Select from a tile's menu: the owner starts Select mode with that
    /// person chosen.
    var onSelect: (_ person: Person) -> Void = { _ in }
    /// Touch and hold an empty cell to add someone there.
    var onAddPerson: (_ cell: Int) -> Void = { _ in }

    init(query: String, isEditing: Bool = false, isListening: Bool = false, isSelecting: Bool = false,
         selection: Binding<Set<UUID>> = .constant([]), showingGames: Bool = false, tilesTurned: Bool = true,
         onSelect: @escaping (_ person: Person) -> Void = { _ in },
         onAddPerson: @escaping (_ cell: Int) -> Void = { _ in }) {
        self.query = query
        self.isEditing = isEditing
        self.isListening = isListening
        self.isSelecting = isSelecting
        _selection = selection
        self.showingGames = showingGames
        self.tilesTurned = tilesTurned
        self.onSelect = onSelect
        self.onAddPerson = onAddPerson
    }

    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    @State private var dropTarget: Int?
    @State private var addingNoteFor: Person?
    @State private var deleting: Person?
    /// While a group is dragged, the cells it would land on.
    @State private var groupTarget = Set<Int>()
    /// The tile whose drag preview was last made: the one being dragged.
    @State private var dragging: UUID?
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
            .onChange(of: isEditing) { _, editing in
                if !editing { selection = [] }
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
                                guard !showingGames, !isEditing, !isSelecting else { return }
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
                            .modifier(TileFlipFace(side: .front, showingBack: showingGames && tilesTurned,
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

                    ForEach(Array(dropTarget.map { groupTarget.isEmpty ? [$0] : groupTarget } ?? []), id: \.self) { cell in
                        Rectangle()
                            .strokeBorder(.tint, lineWidth: 3)
                            .frame(width: squareSize, height: squareSize)
                            .offset(origin(cell))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: CGFloat(cellCount / columns) * pitch, alignment: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items)
                .animation(.snappy, value: isEditing)
                .animation(.snappy, value: isSelecting)
                .animation(.snappy, value: selection)
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

    /// A dragged tile lands on `cell`; a selected one brings the rest of
    /// the selection with it.
    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        groupTarget = []
        if selection.contains(id) {
            store.moveTiles(personIDs: selection, dragging: id, toCell: cell)
        } else {
            store.moveTile(personID: id, toCell: cell)
        }
        return true
    }

    /// Marks `cell` as the drop target, with the outline of the whole
    /// selection when the tile being dragged is part of it.
    private func target(_ cell: Int, _ targeted: Bool) {
        if targeted {
            dropTarget = cell
            groupTarget = groupCells(landingOn: cell)
        } else if dropTarget == cell {
            dropTarget = nil
            groupTarget = []
        }
    }

    /// Where the selection would sit with the dragged tile on `cell`.
    private func groupCells(landingOn cell: Int) -> Set<Int> {
        guard selection.count > 1, let dragging, selection.contains(dragging) else { return [] }
        let anchors = TileLayout.anchors(for: store.people)
        guard let source = anchors[dragging],
              let moved = TileLayout.shifted(selection, from: source, to: cell, anchors: anchors) else { return [] }
        return Set(moved.values)
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
        let isSelected = selection.contains(person.id)
        return Group {
            if isSelecting || isEditing {
                Button { toggle(person) } label: {
                    PersonTile(person: person, size: size)
                        .contentShape(Rectangle())
                }
            } else if isListening {
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
        .scaleEffect(sounding == person.id ? 0.92 : isSelecting && isSelected ? 0.9 : 1)
        .opacity(isSelecting && !isSelected && !selection.isEmpty ? 0.55 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: sounding == person.id)
        .overlay(alignment: .topLeading) { deleteBadge(for: person) }
        .overlay(alignment: .topTrailing) { selectionBadge(for: person, isSelected: isSelected) }
        .overlay {
            if isSelected {
                Rectangle().strokeBorder(.tint, lineWidth: 3)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .contextMenu { if !isSelecting { tileMenu(for: person, colorIndex: colorIndex) } }
        .draggable(person.id.uuidString) {
            // The preview is made as the drag begins, which is the one
            // moment the dragged tile is known before the drop.
            PersonTile(person: person, size: size)
                .onAppear { dragging = person.id }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile")
        .accessibilityHint(isSelecting || isEditing
                           ? (isSelected ? "Selected. Tap to deselect; drag to move the selection together." : "Tap to select; drag to move it.")
                           : isListening ? "Plays \(person.name)'s ditty."
                           : "Opens \(person.name). Touch and hold for a new note, the ditty, the color, turning, or deleting; drag to move it.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

    /// Edit and Select modes' tap: in or out of the selection.
    private func toggle(_ person: Person) {
        UISelectionFeedbackGenerator().selectionChanged()
        if selection.contains(person.id) {
            selection.remove(person.id)
        } else {
            selection.insert(person.id)
        }
    }

    @ViewBuilder
    private func selectionBadge(for person: Person, isSelected: Bool) -> some View {
        if isSelecting || (isEditing && isSelected) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.tact(.title2))
                .symbolRenderingMode(.palette)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.9)),
                                 isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.black.opacity(0.35)))
                .padding(6)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func deleteBadge(for person: Person) -> some View {
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

    @ViewBuilder
    private func tileMenu(for person: Person, colorIndex: Binding<Int>) -> some View {
        Button { addingNoteFor = person } label: {
            Label("New Note", systemImage: "square.and.pencil")
        }
        Button { DittyPlayer.play(person) } label: {
            Label("Play Ditty", systemImage: "music.note")
        }
        Button { onSelect(person) } label: {
            Label("Select", systemImage: "checklist")
        }
        Divider()
        Menu {
            tileChoices(for: person)
        } label: {
            Label("Change Tile", systemImage: "square.on.square")
        }
        // Monochrome has one colour, so there is nothing to choose.
        if !palette.isMonochrome {
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
        }
        Button { store.updateTile(forPersonID: person.id) { $0.rotate() } } label: {
            Label("Rotate", systemImage: "rotate.right")
        }
        Divider()
        Button(role: .destructive) { deleting = person } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// The motifs a tile can change to: the built-in patterns, then the
    /// saved FatBits patterns, each pictured in the person's colour. The
    /// person's page has the rest: photos, drawing in FatBits.
    @ViewBuilder
    private func tileChoices(for person: Person) -> some View {
        let colorIndex = person.tile.colorIndex
        let available = store.availablePatterns(excluding: [person.id])
        ForEach(TilePattern.allCases, id: \.self) { pattern in
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) {
                    $0.pattern = pattern.rawValue
                    $0.showsPhoto = false
                    $0.revertToPattern()
                }
            } label: {
                Label { Text(pattern.title) } icon: {
                    Image(uiImage: TileMenuImage.motif(pattern: pattern, colorIndex: colorIndex))
                }
            }
        }
        if !available.isEmpty {
            Divider()
            ForEach(available) { saved in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    store.applyPattern(id: saved.id, toPersonID: person.id)
                } label: {
                    Label { Text(saved.name) } icon: {
                        Image(uiImage: TileMenuImage.motif(bits: saved.bits, pattern: person.tilePattern, colorIndex: colorIndex))
                    }
                }
            }
        }
    }
}
