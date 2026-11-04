import SwiftUI

/// The root screen: the people as a grid of tiles (People), as a list with
/// their notes (Notes), or a game on the back of the tiles (Games), picked
/// by the floating switch at the bottom and remembered, under the shared
/// header. Everything else is pushed from here.
struct PeopleRootView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var rememberedLayout: PeopleLayout = .standard
    @AppStorage(TileGame.storageKey) private var selectedGameID = TileGame.all[0].id
    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var editMode: EditMode = .inactive
    /// Listen mode: tapping a person plays their ditty instead of opening them.
    @State private var listening = false
    /// Select mode: tapping tiles gathers them; the bar below the grid
    /// changes all of them at once.
    @State private var selecting = false
    @State private var selectedIDs = Set<UUID>()
    /// New Person is showing: where the tile goes and how it starts.
    @State private var addingPerson: AddPersonRequest?
    @State private var showingAddNote = false
    @State private var showingSettings = false
    /// What the canvas shows right now. Mode changes are staged through the
    /// tiles: a game flips them over, and any other mode flips them back
    /// before the list slides in, so every change passes through the flip.
    @State private var canvasShowsGames = false
    /// The list is on screen. The whole screen slides like a page: the
    /// canvas goes off to the left as the list comes in from the right.
    @State private var showsList = false
    @State private var stagedChange = 0
    /// The view is changing because of what was searched for, so the
    /// search must survive the change.
    @State private var switchingForSearch = false
    /// The canvas width, for telling where an edge swipe began.
    @State private var canvasWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: PeopleLayout { rememberedLayout.resolved }

    /// How long the whole wave takes: the last cell's stagger plus one turn.
    static let flipDuration = TileFlipFace.delay(forCell: TileLayout.columns * 4 - 1, columns: TileLayout.columns)
        + TileFlipFace.halfDuration * 2
    /// The page slide between the tiles and the list.
    static let slideDuration = 0.4
    private var query: String { isSearching ? searchText : "" }

    var body: some View {
        NavigationStack(path: $path) {
            HeaderScreen {
                header
            } content: {
                if isSearching {
                    recentTags
                }
                let slidOff = showsList && !reduceMotion
                ZStack {
                    // The grid and the games share one canvas: a game is the
                    // back of the tiles, and choosing one turns them over. The
                    // canvas stays while the list shows, slid off to the left,
                    // so games keep their progress.
                    ZStack {
                        PeopleGridContent(query: query, isEditing: editMode.isEditing && !showsList,
                                          isListening: listening && !showsList,
                                          isSelecting: selecting && !showsList, selection: $selectedIDs,
                                          showingGames: canvasShowsGames,
                                          tilesTurned: GamesSurface.isAvailable(gameID: selectedGameID, tileCount: store.people.count),
                                          onSelect: { person in
                            // Select from a tile's menu: into Select mode with that tile chosen.
                            withAnimation(.snappy) {
                                stopListening()
                                editMode = .inactive
                                selecting = true
                                selectedIDs = [person.id]
                            }
                        }) { cell, seed in
                            addingPerson = AddPersonRequest(cell: cell, seed: seed)
                        }
                        GamesSurface(showing: canvasShowsGames, selectedGameID: selectedGameID)
                    }
                    .visualEffect { content, proxy in
                        content.offset(x: slidOff ? -proxy.size.width : 0)
                    }
                    .opacity(showsList && reduceMotion ? 0 : 1)
                    .allowsHitTesting(!showsList)
                    .accessibilityHidden(showsList)
                    if showsList {
                        PeopleListContent(query: query, editMode: $editMode, isListening: listening)
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                            .zIndex(1)
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { canvasWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, width in canvasWidth = width }
                    }
                }
                .simultaneousGesture(edgeSwipe, including: edgeSwipeEnabled ? .all : .subviews)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if selecting && !showsList && !canvasShowsGames {
                        TileSelectionBar(selection: $selectedIDs, candidates: shownPeopleIDs) {
                            withAnimation(.snappy) { stopSelecting() }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        ViewSwitch(layout: layoutBinding, selectedGameID: $selectedGameID)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 8)
                .animation(.snappy, value: selecting)
            }
            .environment(\.editMode, $editMode)
            .environment(\.pushRoute) { path.append($0) }
            .environment(\.searchTag) { tag in
                path = NavigationPath()
                withAnimation(.snappy) {
                    isSearching = true
                    searchText = "#" + tag
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .sheet(item: $addingPerson) { request in
                NewPersonSheet(seed: request.seed) { name, colorIndex, pattern, bits in
                    if let person = store.addPerson(named: name, colorIndex: colorIndex, pattern: pattern, bits: bits),
                       let cell = request.cell {
                        store.moveTile(personID: person.id, toCell: cell)
                    }
                }
            }
            .sheet(isPresented: $showingAddNote) { NewNoteSheet() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .onAppear {
                canvasShowsGames = layout == .games
                showsList = layout == .list
            }
            .onChange(of: layout) { from, to in
                stage(from: from, to: to)
                editMode = .inactive
                stopListening()
                stopSelecting()
                // A search brings its view with it; any other change of
                // view ends the search.
                if switchingForSearch {
                    switchingForSearch = false
                } else {
                    isSearching = false
                    searchText = ""
                }
            }
            .onChange(of: searchText) { _, text in
                followSearch(text)
            }
        }
    }

    private var header: some View {
        TactHeader(title: "", searchText: $searchText, isSearching: $isSearching,
                   badge: layout.resolved == .games ? TileGame.named(selectedGameID).headerBadge : nil,
                   onLogoTap: popToRoot) {
            ForEach(HeaderAction.actions(for: layout), id: \.self) { action in
                button(for: action)
            }
        }
        .animation(.snappy, value: isSearching)
    }

    @ViewBuilder
    private func button(for action: HeaderAction) -> some View {
        switch action {
        case .search:
            HeaderIconButton(title: isSearching ? "Close Search" : "Search",
                             systemImage: isSearching ? "xmark.circle" : action.systemImage,
                             isActive: isSearching) {
                withAnimation(.snappy) {
                    isSearching.toggle()
                    if !isSearching { searchText = "" }
                }
            }
        case .add:
            Menu {
                Button { addingPerson = AddPersonRequest() } label: {
                    Label("New Person", systemImage: "person.badge.plus")
                }
                Button { showingAddNote = true } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            } label: {
                HeaderIconButton(title: "Add", systemImage: action.systemImage) {}
            }
            .accessibilityLabel("Add")
            .accessibilityHint("New person or new note")
        case .more:
            Menu {
                ForEach(HeaderAction.moreItems(for: layout), id: \.self) { item in
                    switch item {
                    case .edit:
                        Button {
                            withAnimation(.snappy) {
                                stopListening()
                                stopSelecting()
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                        } label: {
                            Label(editMode.isEditing ? "Done" : "Edit",
                                  systemImage: editMode.isEditing ? "checkmark.circle" : "pencil")
                        }
                    case .select:
                        Button {
                            withAnimation(.snappy) {
                                if selecting {
                                    stopSelecting()
                                } else {
                                    stopListening()
                                    editMode = .inactive
                                    selecting = true
                                }
                            }
                        } label: {
                            Label(selecting ? "Done Selecting" : "Select",
                                  systemImage: selecting ? "checkmark.circle" : "checklist")
                        }
                        .disabled(store.people.isEmpty)
                    case .listen:
                        Button {
                            withAnimation(.snappy) {
                                if listening {
                                    stopListening()
                                } else {
                                    editMode = .inactive
                                    stopSelecting()
                                    listening = true
                                }
                            }
                        } label: {
                            Label(listening ? "Stop Listening" : "Listen",
                                  systemImage: listening ? "ear.trianglebadge.exclamationmark" : "ear")
                        }
                    case .bringTogether:
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                store.bringTilesTogether()
                            }
                        } label: {
                            Label("Bring Together", systemImage: "square.grid.3x3.topleft.filled")
                        }
                        .disabled(store.people.count < 2 || !query.isEmpty || TileLayout.isCompact(store.people))
                    case .turnOver:
                        Button {
                            withAnimation(.snappy) { rememberedLayout = .grid }
                        } label: {
                            Label("Turn Tiles Over", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                    case .settings:
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
            } label: {
                HeaderIconButton(title: "More",
                                 systemImage: editMode.isEditing || selecting ? "checkmark.circle" : listening ? "ear" : action.systemImage,
                                 isActive: editMode.isEditing || listening || selecting) {}
            }
            .accessibilityLabel("More")
            .accessibilityHint(editMode.isEditing ? "Done editing, or settings"
                               : selecting ? "Done selecting, or settings"
                               : listening ? "Stop listening, or settings"
                               : layout.resolved == .games ? "Turn the tiles over, or settings"
                               : "Edit, select, listen, or settings")
        }
    }

    /// A search over a game turns the tiles back so the matching people can
    /// be seen. A tag search shows people too, tagged themselves or through
    /// their notes, so it stays in whichever of People or Notes is open.
    private func followSearch(_ text: String) {
        guard layout == .games, !PeopleSearch.normalized(text).isEmpty else { return }
        let wanted = PeopleLayout.grid
        guard layout != wanted else { return }
        switchingForSearch = true
        withAnimation(.snappy) { rememberedLayout = wanted }
    }

    /// Moves the canvas to `to` in steps. Leaving a game turns the tiles
    /// back first, then the screen slides over to the list; leaving the
    /// list slides back to the tiles, then a game turns them over.
    private func stage(from: PeopleLayout, to: PeopleLayout) {
        stagedChange += 1
        let change = stagedChange
        func later(_ seconds: Double, _ action: @escaping () -> Void) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                if stagedChange == change { action() }
            }
        }
        /// Slides the whole screen to the list or back to the tiles. With
        /// Reduce Motion the two cross-fade instead.
        func slide(toList: Bool) {
            let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: Self.slideDuration)
            withAnimation(animation) { showsList = toList }
        }
        switch (from, to) {
        case (.games, .list):
            canvasShowsGames = false
            later(Self.flipDuration) { slide(toList: true) }
        case (.list, .games):
            slide(toList: false)
            later(Self.slideDuration) { canvasShowsGames = true }
        case (.list, _):
            slide(toList: false)
        case (_, .games):
            canvasShowsGames = true
        case (_, .list):
            slide(toList: true)
        default:
            canvasShowsGames = false
        }
    }

    /// While searching: the tags in use, most used first, narrowed to what
    /// follows a typed `#`. Tapping one searches for it; again clears.
    @ViewBuilder
    private var recentTags: some View {
        let counts = store.tagCounts
        let typed = NoteTags.isTagQuery(searchText) ? String(searchText.dropFirst()) : ""
        let shown = TagCount.matching(typed, in: counts)
        if !shown.isEmpty && (typed.isEmpty || NoteTags.isTagQuery(searchText)) {
            TagRow(tags: shown, selected: NoteTags.queryTag(searchText)) { tag in
                withAnimation(.snappy) {
                    searchText = NoteTags.queryTag(searchText) == NoteTags.normalized(tag) ? "" : "#" + tag
                }
            }
            .background(Color.tactBackground)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Edge swipes switch views only when nothing else owns the touch:
    /// not while editing or selecting, where tiles are being moved or picked.
    private var edgeSwipeEnabled: Bool {
        !editMode.isEditing && !selecting
    }

    /// Swipe in from the right edge over the tiles for the list; from the
    /// left edge over the list for the tiles.
    private var edgeSwipe: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onEnded { value in
                guard edgeSwipeEnabled,
                      EdgeSwipe.begins(in: layout, startX: value.startLocation.x, width: canvasWidth),
                      let target = EdgeSwipe.target(from: layout,
                                                    startX: value.startLocation.x,
                                                    translation: value.translation,
                                                    predictedTranslation: value.predictedEndTranslation,
                                                    width: canvasWidth)
                else { return }
                withAnimation(.snappy) { rememberedLayout = target }
            }
    }

    /// The people on the grid right now, in cell order: what Select All gathers.
    private var shownPeopleIDs: [UUID] {
        PeopleGridItems(people: store.people, notes: store.notes, query: query).tiles.map(\.person.id)
    }

    /// Ends Select mode and lets the selection go.
    private func stopSelecting() {
        guard selecting || !selectedIDs.isEmpty else { return }
        selecting = false
        selectedIDs = []
    }

    /// Ends Listen mode and any ditty that is sounding.
    private func stopListening() {
        guard listening else { return }
        listening = false
        DittyPlayer.stop()
    }

    private var layoutBinding: Binding<PeopleLayout> {
        Binding(get: { layout }, set: { rememberedLayout = $0 })
    }

    private func popToRoot() {
        path = NavigationPath()
        withAnimation(.snappy) { rememberedLayout = .grid }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .person(let id):
            PersonDetailView(personID: id)
        case .note(let id):
            NoteDetailView(noteID: id)
        }
    }
}

/// A request to add someone: the empty cell their tile goes in, if one was
/// chosen, and the tile look to start from, if the grid showed one.
private struct AddPersonRequest: Identifiable {
    let id = UUID()
    var cell: Int?
    var seed: Int?
}
