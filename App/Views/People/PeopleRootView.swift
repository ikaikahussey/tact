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
    @State private var showingAddPerson = false
    @State private var showingAddNote = false
    @State private var showingSettings = false
    @State private var newPersonName = ""
    /// The empty cell that was held to add someone; their tile goes there.
    @State private var addPersonCell: Int?
    /// What the canvas shows right now. Mode changes are staged through the
    /// tiles: a game flips them over, and any other mode flips them back
    /// before the list fades in, so every change passes through the flip.
    @State private var canvasShowsGames = false
    /// The list is in the hierarchy (laid out, so its rows report where
    /// their avatars are) and whether it can be seen.
    @State private var showsList = false
    @State private var listVisible = false
    /// Tiles sliding between their grid cells and their list rows.
    @State private var flight: TileFlight?
    @State private var avatarFrames = AvatarFrames()
    @State private var stagedChange = 0
    /// The view is changing because of what was searched for, so the
    /// search must survive the change.
    @State private var switchingForSearch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: PeopleLayout { rememberedLayout.resolved }

    /// How long the whole wave takes: the last cell's stagger plus one turn.
    static let flipDuration = TileFlipFace.delay(forCell: TileLayout.columns * 4 - 1, columns: TileLayout.columns)
        + TileFlipFace.halfDuration * 2
    private var query: String { isSearching ? searchText : "" }

    var body: some View {
        NavigationStack(path: $path) {
            HeaderScreen {
                header
            } content: {
                if isSearching {
                    recentTags
                }
                ZStack {
                    // The grid and the games share one canvas: a game is the
                    // back of the tiles, and choosing one turns them over. The
                    // canvas stays while the list shows, so games keep their
                    // progress. While tiles are in flight both the canvas and
                    // the list are hidden and the overlay carries the tiles.
                    ZStack {
                        PeopleGridContent(query: query, isEditing: editMode.isEditing && !showsList,
                                          showingGames: canvasShowsGames) { cell in
                            addPersonCell = cell
                            showingAddPerson = true
                        }
                        GamesSurface(showing: canvasShowsGames, selectedGameID: selectedGameID)
                    }
                    .opacity(flight == nil && !listVisible ? 1 : 0)
                    .allowsHitTesting(!showsList && flight == nil)
                    .accessibilityHidden(showsList)
                    if showsList {
                        PeopleListContent(query: query, editMode: $editMode)
                            .opacity(listVisible ? 1 : 0)
                            .allowsHitTesting(listVisible)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: listVisible)
                .overlayPreferenceValue(TileAnchors.self) { tiles in
                    if let flight {
                        TileFlightOverlay(flight: flight, people: store.people, tiles: tiles,
                                          avatars: avatarFrames.frames)
                    }
                }
                .environment(avatarFrames)
            }
            .safeAreaInset(edge: .bottom) {
                ViewSwitch(layout: layoutBinding, selectedGameID: $selectedGameID)
                    .padding(.bottom, 8)
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
            .alert("Add Person", isPresented: $showingAddPerson) {
                TextField("Name", text: $newPersonName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    newPersonName = ""
                    addPersonCell = nil
                }
                Button("Add") {
                    if let person = store.addPerson(named: newPersonName), let cell = addPersonCell {
                        store.moveTile(personID: person.id, toCell: cell)
                    }
                    newPersonName = ""
                    addPersonCell = nil
                }
            }
            .sheet(isPresented: $showingAddNote) { NewNoteSheet() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .onAppear {
                canvasShowsGames = layout == .games
                showsList = layout == .list
                listVisible = showsList
            }
            .onChange(of: layout) { from, to in
                stage(from: from, to: to)
                editMode = .inactive
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
        TactHeader(title: "", searchText: $searchText, isSearching: $isSearching, onLogoTap: popToRoot) {
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
                Button { showingAddPerson = true } label: {
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
                            withAnimation(.snappy) { editMode = editMode.isEditing ? .inactive : .active }
                        } label: {
                            Label(editMode.isEditing ? "Done" : "Edit",
                                  systemImage: editMode.isEditing ? "checkmark.circle" : "pencil")
                        }
                    case .settings:
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
            } label: {
                HeaderIconButton(title: "More", systemImage: editMode.isEditing ? "checkmark.circle" : action.systemImage,
                                 isActive: editMode.isEditing) {}
            }
            .accessibilityLabel("More")
            .accessibilityHint(editMode.isEditing ? "Done editing, or settings" : "Edit or settings")
        }
    }

    /// A search for a tag is a search through notes, so it always shows
    /// the list; any other search over a game turns the tiles back so the
    /// matching people can be seen.
    private func followSearch(_ text: String) {
        let wanted: PeopleLayout
        if NoteTags.queryTag(text) != nil {
            wanted = .list
        } else if layout == .games, !PeopleSearch.normalized(text).isEmpty, !NoteTags.isTagQuery(text) {
            wanted = .grid
        } else {
            return
        }
        guard layout != wanted else { return }
        switchingForSearch = true
        withAnimation(.snappy) { rememberedLayout = wanted }
    }

    /// Moves the canvas to `to` in steps. Leaving a game turns the tiles
    /// back first, then the tiles slide into their list rows; leaving the
    /// list slides them back to their cells, then a game turns them over.
    private func stage(from: PeopleLayout, to: PeopleLayout) {
        stagedChange += 1
        let change = stagedChange
        func later(_ seconds: Double, _ action: @escaping () -> Void) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                if stagedChange == change { action() }
            }
        }
        /// Tiles fly from the grid into the list. The list is laid out
        /// unseen first so its rows can say where their avatars are.
        func flyToList() {
            showsList = true
            listVisible = false
            guard !reduceMotion else { listVisible = true; return }
            later(0.08) {
                flight = TileFlight(toList: true)
                later(0.02) { withAnimation { flight?.progress = 1 } }
                later(TileFlight.duration + 0.05) {
                    listVisible = true
                    flight = nil
                }
            }
        }
        /// Tiles fly from the list back to the grid, then `then` runs.
        func flyToGrid(then: @escaping () -> Void) {
            listVisible = false
            guard !reduceMotion else { showsList = false; then(); return }
            flight = TileFlight(toList: false)
            later(0.02) { withAnimation { flight?.progress = 1 } }
            later(TileFlight.duration + 0.05) {
                showsList = false
                flight = nil
                then()
            }
        }
        flight = nil
        switch (from, to) {
        case (.games, .list):
            canvasShowsGames = false
            later(Self.flipDuration) { flyToList() }
        case (.list, .games):
            flyToGrid { later(0.1) { canvasShowsGames = true } }
        case (.list, _):
            flyToGrid {}
        case (_, .games):
            canvasShowsGames = true
        case (_, .list):
            flyToList()
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
