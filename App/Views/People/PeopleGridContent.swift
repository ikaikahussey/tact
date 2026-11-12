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
/// Tiles can be grouped into a stack (Stack on the Select bar), which
/// takes one cell and shows its first four tiles scaled down, or a design
/// chosen from its menu. Dragging a tile onto a stack adds it. A stack
/// can be given a tag from its menu: everyone in it gets the tag, and from
/// then on everyone carrying the tag is in the stack, so a person can be
/// in several tag stacks at once (`TagStack`). A
/// tap opens it: the rows below move down and the stack's tiles are laid
/// out in a tray under its row (`StackTray`). There a tap opens a person
/// as usual, and a tile leaves the stack from its menu or by being dragged
/// out onto the canvas. Another tap on the stack closes it.
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
    /// Touch and hold an empty cell to add someone there. From the cursor
    /// tile, `seed` is that tile's look, so the new person starts with it.
    var onAddPerson: (_ cell: Int, _ seed: Int?) -> Void = { _, _ in }

    init(query: String, isEditing: Bool = false, isListening: Bool = false, isSelecting: Bool = false,
         selection: Binding<Set<UUID>> = .constant([]), showingGames: Bool = false, tilesTurned: Bool = true,
         onSelect: @escaping (_ person: Person) -> Void = { _ in },
         onAddPerson: @escaping (_ cell: Int, _ seed: Int?) -> Void = { _, _ in }) {
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
    @Environment(\.displayScale) private var displayScale
    @State private var dropTarget: Int?
    /// The look of the blinking tile shown before anyone is added.
    @State private var cursorSeed = NewPersonSheet.randomSeed()
    @State private var addingNoteFor: Person?
    @State private var deleting: Person?
    /// While a group is dragged, the cells it would land on.
    @State private var groupTarget = Set<Int>()
    /// The tile whose drag preview was last made: the one being dragged.
    @State private var dragging: UUID?
    /// The person whose ditty is sounding in Listen mode, for the pulse.
    @State private var sounding: UUID?
    /// The stack whose tiles are laid out in the tray.
    @State private var openStack: UUID?
    /// What a tile dragged out of the tray carries, before its id, so the
    /// drop takes it out of the stack instead of moving the stack.
    static let memberPrefix = "stack-member:"
    /// The stack being given a tag, and the tag as typed.
    @State private var taggingStack: UUID?
    @State private var tagText = ""
    /// How large the tiles are drawn, 1 being four across the screen.
    /// Zooming out shows more rows at once on a tall board; the controls
    /// appear once the board is past `zoomRows` rows. Games are played at
    /// full size, since their cells line up with the tiles' cells.
    @AppStorage(Self.zoomKey) private var zoom = 1.0
    static let zoomKey = "tileZoom"
    static let zoomLevels: [Double] = [1, 0.75, 0.5]
    static let zoomRows = 8

    private let columns = TileLayout.columns
    private let spacing = TileLayout.spacing

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
        tagAlert(tiles)
            .background(Color.tactBackground)
            .overlay(alignment: .bottomTrailing) {
                if !showingGames, Self.rows(occupied: TileLayout.cells(for: store.people, tagStacks: store.tagStacks).keys, columns: columns) > Self.zoomRows {
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
    }

    private var tiles: some View {
        GeometryReader { geometry in
            // One board, or across a fold a spread of two pages; the games
            // use the same layout.
            let layout = BoardLayout.make(size: geometry.size, fold: geometry.verticalFold, zoom: effectiveZoom)
            let squareSize = layout.cellSide
            let visibleRows = layout.visibleRows(height: geometry.size.height)
            let items = PeopleGridItems(people: store.people, notes: store.notes, query: query, tagStacks: store.tagStacks)
            let cellCount = layout.filledRows(atLeast: Self.cellCount(occupied: items.occupiedCells, visibleRows: visibleRows,
                                                                      columns: columns) / columns) * columns
            let open: PeopleGridItems.Tile? = openTile(in: items)
            let tray: StackTray? = open.map { StackTray(cell: $0.cell, count: $0.stack.count) }
            let origin = { (cell: Int) -> CGSize in
                let point = layout.origin(of: cell, tray: tray)
                return CGSize(width: point.x, height: point.y)
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
                                onAddPerson(cell, nil)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: cell)
                            } isTargeted: { targeted in
                                target(cell, targeted)
                            }
                            .offset(origin(cell))
                            .accessibilityHidden(true)
                    }

                    // Nobody yet: a patterned tile blinks in the first cell
                    // like a cursor, and a tap adds the first person there
                    // with that tile.
                    if store.people.isEmpty && !showingGames {
                        let art = TileArt(seed: cursorSeed)
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onAddPerson(0, cursorSeed)
                        } label: {
                            ZStack {
                                TileShades(colorIndex: art.colorIndex, palette: palette).pale
                                TileMotifView(pattern: TilePattern(seed: cursorSeed), colorIndex: art.colorIndex)
                            }
                            .frame(width: squareSize, height: squareSize)
                            .cursorBlink()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(origin(0))
                        .accessibilityLabel("Add Your First Person")
                        .accessibilityHint("Each person becomes a patterned tile")
                        .transition(.opacity)
                    }

                    ForEach(items.tiles, id: \.id) { placed in
                        boardTile(placed, size: squareSize)
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

                    if let open, let tray {
                        stackTray(open, tray: tray, layout: layout)
                            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                    }
                }
                .frame(width: geometry.size.width, height: layout.height(rows: cellCount / columns, tray: tray), alignment: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tray)
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
            .onChange(of: openStack) { _, stack in
                // A stack opened low on the screen: scroll its tray into view.
                guard stack != nil else { return }
                DispatchQueue.main.async {
                    withAnimation { proxy.scrollTo(Self.trayID) }
                }
            }
            }
        }
    }

    private static let topID = "tilesTop"
    private static let trayID = "stackTray"

    // MARK: Stacks

    /// The stack that is open, when its tray can show: not under a game,
    /// and not while tiles are being edited or selected.
    private func openTile(in items: PeopleGridItems) -> PeopleGridItems.Tile? {
        guard let openStack, !showingGames, !isEditing, !isSelecting else { return nil }
        return items.tiles.first { $0.isStack && $0.stackID == openStack }
    }

    @ViewBuilder
    private func boardTile(_ placed: PeopleGridItems.Tile, size: CGFloat) -> some View {
        if placed.isStack {
            stackTile(placed, size: size)
        } else {
            tile(for: placed.person, size: size)
        }
    }

    /// A stack on the canvas. A tap opens or closes it; while selecting
    /// or editing, a tap selects everyone in it.
    private func stackTile(_ placed: PeopleGridItems.Tile, size: CGFloat) -> some View {
        let isSelected: Bool = Set(placed.ids).isSubset(of: selection)
        let isOpen: Bool = openStack != nil && placed.stackID == openStack && !isSelecting && !isEditing
        let face = stackFace(placed, size: size, isSelected: isSelected, isOpen: isOpen)
            .contextMenu { if !isSelecting { stackMenu(for: placed, isOpen: isOpen) } }
            .draggable(placed.id.uuidString) {
                StackedTile(people: placed.stack, size: size, design: placed.design, tag: placed.tag)
                    .onAppear { dragging = placed.id }
            }
        return stackAccessibility(face, for: placed, isSelected: isSelected, isOpen: isOpen)
    }

    private func stackFace(_ placed: PeopleGridItems.Tile, size: CGFloat, isSelected: Bool, isOpen: Bool) -> some View {
        let scale: CGFloat = isSelecting && isSelected ? 0.9 : 1
        let dimmed: Bool = isSelecting && !isSelected && !selection.isEmpty
        return Button { tapStack(placed) } label: {
            StackedTile(people: placed.stack, size: size, design: placed.design, tag: placed.tag, isOpen: isOpen)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
        .opacity(dimmed ? 0.55 : 1)
        .overlay(alignment: .topTrailing) { selectionBadge(for: placed.person, isSelected: isSelected) }
        .overlay { selectionRing(isSelected: isSelected) }
    }

    private func stackAccessibility(_ view: some View, for placed: PeopleGridItems.Tile, isSelected: Bool, isOpen: Bool) -> some View {
        let names: String = placed.stack.map(\.name).formatted(.list(type: .and))
        let title: String = placed.tag.map { "Stack \($0), \(placed.stack.count) people" } ?? "Stack of \(placed.stack.count)"
        let label: String = "\(title): \(names)"
        let hint: String = isSelecting || isEditing
            ? (isSelected ? "Selected. Tap to deselect." : "Tap to select everyone in the stack.")
            : (isOpen ? "Closes the stack." : "Opens the stack, moving the tiles below down. Touch and hold for its design or to unstack; drag to move it, or drag a tile onto it to add it.")
        let traits: AccessibilityTraits = isSelected ? [.isButton, .isSelected] : .isButton
        return view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
            .accessibilityAction(named: "Unstack") { unstack(placed) }
    }

    private func tapStack(_ placed: PeopleGridItems.Tile) {
        if isSelecting || isEditing {
            // Everyone in the stack goes in or out together.
            UISelectionFeedbackGenerator().selectionChanged()
            if Set(placed.ids).isSubset(of: selection) {
                selection.subtract(placed.ids)
            } else {
                selection.formUnion(placed.ids)
            }
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openStack = openStack == placed.stackID ? nil : placed.stackID
        }
    }

    private func unstack(_ placed: PeopleGridItems.Tile) {
        guard let stack = placed.stackID else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.unstack(id: stack)
        }
    }

    @ViewBuilder
    private func stackMenu(for placed: PeopleGridItems.Tile, isOpen: Bool) -> some View {
        Button { tapStack(placed) } label: {
            Label(isOpen ? "Close Stack" : "Open Stack", systemImage: "square.stack.3d.up")
        }
        Button {
            tagText = placed.tag.map { "#" + $0 } ?? ""
            taggingStack = placed.stackID
        } label: {
            Label(placed.isTagStack ? "Change Tag…" : "Tag…", systemImage: "number")
        }
        Divider()
        Menu {
            stackDesignChoices(for: placed)
        } label: {
            Label("Design", systemImage: "square.on.square")
        }
        // A design has a color; the tiles keep their own.
        if placed.design != nil, !palette.isMonochrome {
            Menu {
                Picker("Color", selection: stackColor(for: placed)) {
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
        Divider()
        Button { unstack(placed) } label: {
            Label("Unstack", systemImage: "square.stack.3d.up.slash")
        }
    }

    /// Changes the stack's design, starting from the top person's pattern
    /// and color when it has none yet.
    private func setDesign(of placed: PeopleGridItems.Tile, _ change: (inout StackDesign) -> Void) {
        guard let stack = placed.stackID else { return }
        var design = placed.design ?? StackDesign(pattern: placed.person.tilePattern.rawValue,
                                                  colorIndex: placed.person.tile.colorIndex)
        change(&design)
        UISelectionFeedbackGenerator().selectionChanged()
        store.setStackDesign(id: stack, design)
    }

    private func stackColor(for placed: PeopleGridItems.Tile) -> Binding<Int> {
        Binding(
            get: { placed.design?.colorIndex ?? placed.person.tile.colorIndex },
            set: { newValue in setDesign(of: placed) { $0.colorIndex = newValue } }
        )
    }

    /// What a stack can look like: its own tiles scaled down (the
    /// default), a built-in pattern, or a saved FatBits pattern.
    @ViewBuilder
    private func stackDesignChoices(for placed: PeopleGridItems.Tile) -> some View {
        let colorIndex: Int = placed.design?.colorIndex ?? placed.person.tile.colorIndex
        let available = store.availablePatterns()
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            if let stack = placed.stackID { store.setStackDesign(id: stack, nil) }
        } label: {
            Label("Tiles", systemImage: placed.design == nil ? "checkmark" : "square.grid.2x2")
        }
        Divider()
        ForEach(TilePattern.allCases, id: \.self) { pattern in
            Button {
                setDesign(of: placed) {
                    $0.pattern = pattern.rawValue
                    $0.bits = nil
                }
            } label: {
                Label { Text(pattern.title) } icon: {
                    Image(uiImage: TileMenuImage.motif(pattern: pattern, colorIndex: colorIndex, scale: displayScale))
                }
            }
        }
        if !available.isEmpty {
            Divider()
            ForEach(available) { saved in
                Button {
                    setDesign(of: placed) { $0.bits = saved.bits }
                } label: {
                    Label { Text(saved.name) } icon: {
                        Image(uiImage: TileMenuImage.motif(bits: saved.bits, pattern: .cross, colorIndex: colorIndex, scale: displayScale))
                    }
                }
            }
        }
    }

    /// The open stack's tiles, four across, under the stack's row, with a
    /// notch pointing up at the stack.
    private func stackTray(_ open: PeopleGridItems.Tile, tray: StackTray, layout: BoardLayout) -> some View {
        let frame: CGRect = layout.trayFrame(tray)
        let side: CGFloat = layout.cellSide
        let notch: CGFloat = 9
        let notchX: CGFloat = CGFloat(tray.cell % columns) * layout.pitch + side / 2 - notch
        return ZStack(alignment: .topLeading) {
            trayFill
            StackNotch()
                .fill(Color.tactBackground)
                .overlay { StackNotch().fill(palette.accent.opacity(0.16)) }
                .frame(width: notch * 2, height: notch)
                .offset(x: notchX, y: -notch)
                .allowsHitTesting(false)
            ForEach(Array(open.stack.enumerated()), id: \.element.id) { index, person in
                let point: CGPoint = layout.trayOrigin(of: index, in: tray)
                tile(for: person, size: side, in: open)
                    .offset(x: point.x - frame.minX, y: point.y - frame.minY)
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Open stack, \(open.stack.count) people")
        // Padding, not an offset, so the scroll view can bring the tray
        // into view.
        .id(Self.trayID)
        .padding(.leading, max(0, frame.minX))
        .padding(.top, frame.minY)
    }

    /// Takes a person out of a stack; out of a tag stack by taking the
    /// tag off them.
    private func remove(_ person: Person, from stack: PeopleGridItems.Tile) {
        guard let stackID = stack.stackID else { return }
        if stack.isTagStack {
            store.removeFromTagStack(personID: person.id, id: stackID)
        } else {
            store.removeFromStack(personID: person.id)
        }
    }

    /// What a dragged tile carries: the person's id, and from an open
    /// stack the stack's id before it.
    static func payload(for person: Person, in stack: PeopleGridItems.Tile?) -> String {
        guard let stackID = stack?.stackID else { return person.id.uuidString }
        return memberPrefix + stackID.uuidString + ":" + person.id.uuidString
    }

    /// The stack and person a tile dragged out of an open stack carries.
    static func member(in payload: String) -> (stack: UUID, person: UUID)? {
        guard payload.hasPrefix(memberPrefix) else { return nil }
        let parts = payload.dropFirst(memberPrefix.count).split(separator: ":")
        guard parts.count == 2, let stack = UUID(uuidString: String(parts[0])),
              let person = UUID(uuidString: String(parts[1])) else { return nil }
        return (stack, person)
    }

    /// Asks for the stack's tag.
    private func tagAlert(_ content: some View) -> some View {
        let showing = Binding(get: { taggingStack != nil }, set: { if !$0 { taggingStack = nil } })
        return content.alert("Tag Stack", isPresented: showing) {
            TextField("#tag", text: $tagText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { taggingStack = nil }
            Button("Tag") {
                if let stack = taggingStack {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        _ = store.tagStack(id: stack, as: tagText)
                    }
                }
                taggingStack = nil
            }
        } message: {
            Text("Everyone in the stack gets the tag, and everyone with the tag is in the stack.")
        }
    }

    private var trayFill: some View {
        Color.tactBackground
            .overlay { palette.accent.opacity(0.16) }
    }

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

    /// A dragged tile lands on `cell`, shifting the tiles in its way; a
    /// selected one brings the rest of the selection with it.
    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let item = items.first else { return false }
        groupTarget = []
        let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        // The stack sitting on the cell: a drop on it adds to it.
        let target: UUID? = PeopleGridItems(people: store.people, notes: store.notes, query: "", tagStacks: store.tagStacks)
            .tiles.first { $0.cell == cell && $0.isStack }?.stackID
        // A tile dragged out of the open stack leaves it for this cell,
        // or joins the stack on it.
        if item.hasPrefix(Self.memberPrefix) {
            guard let member = Self.member(in: item) else { return false }
            withAnimation(spring) {
                store.moveMember(member.person, ofStack: member.stack, toCell: cell, ontoStack: target)
            }
            return true
        }
        guard let id = UUID(uuidString: item) else { return false }
        // Onto a stack: the tile joins it, with the rest of the selection
        // when it is part of one. Another stack merges in.
        if let target {
            guard id != target, store.person(id: id)?.tile.stack != target else { return false }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(spring) {
                _ = store.addTiles(selection.contains(id) ? selection : [id], toStack: target)
            }
            return true
        }
        // Tiles in the way slide aside to make room.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selection.contains(id) {
                store.moveTiles(personIDs: selection, dragging: id, toCell: cell)
            } else {
                store.moveTile(personID: id, toCell: cell)
            }
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
        let anchors = TileLayout.anchors(for: store.people, tagStacks: store.tagStacks)
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

    // The tile is built in three steps so the compiler type-checks each
    // modifier chain on its own; as one expression it times out.
    private func tile(for person: Person, size: CGFloat, in stack: PeopleGridItems.Tile? = nil) -> some View {
        let colorIndex = Binding(
            get: { person.tile.colorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.colorIndex = newValue }
            }
        )
        let isSelected = selection.contains(person.id)
        let face = tileFace(for: person, size: size, isSelected: isSelected)
            .contextMenu { if !isSelecting { tileMenu(for: person, colorIndex: colorIndex, in: stack) } }
            .draggable(Self.payload(for: person, in: stack)) {
                // The preview is made as the drag begins, which is the one
                // moment the dragged tile is known before the drop.
                PersonTile(person: person, size: size)
                    .onAppear { dragging = person.id }
            }
        return tileAccessibility(face, for: person, isSelected: isSelected)
    }

    /// The tile and its tap, with the press, dimming and badges.
    private func tileFace(for person: Person, size: CGFloat, isSelected: Bool) -> some View {
        let isSounding: Bool = sounding == person.id
        let scale: CGFloat = isSounding ? 0.92 : (isSelecting && isSelected ? 0.9 : 1)
        let dimmed: Bool = isSelecting && !isSelected && !selection.isEmpty
        return tileTap(for: person, size: size)
            .buttonStyle(.plain)
            .scaleEffect(scale)
            .opacity(dimmed ? 0.55 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSounding)
            .overlay(alignment: .topLeading) { deleteBadge(for: person) }
            .overlay(alignment: .topTrailing) { selectionBadge(for: person, isSelected: isSelected) }
            .overlay { selectionRing(isSelected: isSelected) }
    }

    @ViewBuilder
    private func tileTap(for person: Person, size: CGFloat) -> some View {
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

    @ViewBuilder
    private func selectionRing(isSelected: Bool) -> some View {
        if isSelected {
            Rectangle().strokeBorder(.tint, lineWidth: 3)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func tileHint(for person: Person, isSelected: Bool) -> String {
        if isSelecting || isEditing {
            return isSelected ? "Selected. Tap to deselect; drag to move the selection together." : "Tap to select; drag to move it."
        }
        if isListening { return "Plays \(person.name)'s ditty." }
        return "Opens \(person.name). Touch and hold for a new note, the ditty, the color, turning, or deleting; drag to move it."
    }

    private func tileAccessibility(_ view: some View, for person: Person, isSelected: Bool) -> some View {
        let label: String = "\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile"
        let traits: AccessibilityTraits = isSelected ? [.isButton, .isSelected] : .isButton
        return view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(tileHint(for: person, isSelected: isSelected))
            .accessibilityAddTraits(traits)
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
    private func tileMenu(for person: Person, colorIndex: Binding<Int>, in stack: PeopleGridItems.Tile? = nil) -> some View {
        Button { addingNoteFor = person } label: {
            Label("New Note", systemImage: "square.and.pencil")
        }
        Button { DittyPlayer.play(person) } label: {
            Label("Play Ditty", systemImage: "music.note")
        }
        if let stack {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    remove(person, from: stack)
                }
            } label: {
                Label(stack.tag.map { "Remove from #\($0)" } ?? "Remove from Stack", systemImage: "square.stack.3d.up.slash")
            }
        } else {
            Button { onSelect(person) } label: {
                Label("Select", systemImage: "checklist")
            }
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
                    Image(uiImage: TileMenuImage.motif(pattern: pattern, colorIndex: colorIndex, scale: displayScale))
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
                        Image(uiImage: TileMenuImage.motif(bits: saved.bits, pattern: person.tilePattern, colorIndex: colorIndex, scale: displayScale))
                    }
                }
            }
        }
    }
}

/// The small triangle joining the tray to its stack.
private struct StackNotch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
