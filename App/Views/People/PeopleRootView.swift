import SwiftUI

/// The root screen: the people as a grid of tiles (People), as a list with
/// their notes (Notes), or the games (Games), under the shared header,
/// which remembers the choice. Everything else is pushed from here.
struct PeopleRootView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var rememberedLayout: PeopleLayout = .standard
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
                switch layout {
                case .list:
                    PeopleListContent(query: query, editMode: $editMode)
                case .games:
                    GamesContent()
                default:
                    PeopleGridContent(query: query, isEditing: editMode.isEditing)
                }
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
        TactHeader(title: layout.viewTitle,
                   layout: Binding(get: { layout }, set: { newValue in
                       UISelectionFeedbackGenerator().selectionChanged()
                       withAnimation(.snappy) { rememberedLayout = newValue }
                   }),
                   searchText: $searchText, isSearching: $isSearching, onLogoTap: popToRoot) {
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
        case .tangram:
            GameScreen(title: route.title, onLogoTap: popToRoot) { context in
                TangramGridContent(context: context)
            }
        case .slidingPuzzle(let source):
            GameScreen(title: route.title, onLogoTap: popToRoot) { context in
                SlidingPuzzleGame(context: context, source: source)
            }
        }
    }
}
