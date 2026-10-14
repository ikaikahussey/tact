import SwiftUI

/// The People tab. Switches between the list and the Tiles canvas and hosts
/// the shared "Add Person" and settings actions.
struct PeopleTabView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var layout: PeopleLayout = .list
    @State private var showingAddPerson = false
    @State private var showingSettings = false
    @State private var newPersonName = ""

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
                case .grid, .art, .colors:
                    PeopleGridContent()
                case .flashcards:
                    FlashcardView()
                }
            }
            .background(Color.tactBackground)
            .navigationTitle("People")
            .appTitleBar()
            .toolbar {
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

            .onAppear {
                // The Art Puzzle layout is gone; open the Tiles canvas instead.
                if layout == .art { layout = .grid }
            }
        }
    }
}
