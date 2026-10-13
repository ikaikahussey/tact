import SwiftUI

/// The People tab. Switches between the list and the game-style layouts and
/// hosts the shared "Add Person" and settings actions.
struct PeopleTabView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var layout: PeopleLayout = .list
    @State private var showingAddPerson = false
    @State private var showingSettings = false
    @State private var newPersonName = ""
    @State private var isJiggleMode = false

    /// "People" with a chevron: tapping opens the view-mode menu.
    private var header: some View {
        Menu {
            Picker("View", selection: $layout) {
                ForEach(PeopleLayout.available) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
            Divider()
            Button { showingSettings = true } label: {
                Label("Settings…", systemImage: "gearshape")
            }
        } label: {
            TabHeader("People") {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("People, \(layout.resolved.title)")
        .accessibilityHint("Changes how people are shown")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                switch layout.resolved {
                case .list:
                    PeopleListContent()
                case .grid:
                    PeopleGridContent(tileStyle: .photo, isJiggleMode: $isJiggleMode) { showingAddPerson = true }
                case .colors:
                    PeopleGridContent(tileStyle: .color(store.settings.randomColorSettings.palette),
                                      isJiggleMode: $isJiggleMode) { showingAddPerson = true }
                case .flashcards:
                    FlashcardView()
                case .art:
                    ArtPuzzleView()
                }
            }
            .background(Color.tactBackground)
            .navigationTitle("People")
            .appTitleBar()
            .toolbar {
                if isJiggleMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { withAnimation { isJiggleMode = false } }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddPerson = true } label: {
                        Label("Add Person", systemImage: "plus")
                    }
                }
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: layout) { _, _ in isJiggleMode = false }
        }
    }
}
