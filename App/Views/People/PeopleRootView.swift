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

    private var layout: PeopleLayout { rememberedLayout.resolved }
    private var query: String { isSearching ? searchText : "" }

    var body: some View {
        NavigationStack(path: $path) {
            HeaderScreen {
                header
            } content: {
                if layout == .list {
                    PeopleListContent(query: query, editMode: $editMode)
                } else {
                    // The grid and the games share one canvas: a game is the
                    // back of the tiles, and choosing one turns them over.
                    ZStack {
                        PeopleGridContent(query: query, isEditing: editMode.isEditing, showingGames: layout == .games)
                        GamesSurface(showing: layout == .games, selectedGameID: selectedGameID)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ViewSwitch(layout: layoutBinding, selectedGameID: $selectedGameID)
                    .padding(.bottom, 8)
            }
            .environment(\.editMode, $editMode)
            .environment(\.pushRoute) { path.append($0) }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .alert("Add Person", isPresented: $showingAddPerson) {
                TextField("Name", text: $newPersonName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) { newPersonName = "" }
                Button("Add") {
                    store.addPerson(named: newPersonName)
                    newPersonName = ""
                }
            }
            .sheet(isPresented: $showingAddNote) { NewNoteSheet() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .onChange(of: layout) { _, _ in
                editMode = .inactive
                isSearching = false
                searchText = ""
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
