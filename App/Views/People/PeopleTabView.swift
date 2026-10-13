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

    var body: some View {
        NavigationStack {
            Group {
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
            .navigationTitle("Tact")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isJiggleMode {
                        Button("Done") { withAnimation { isJiggleMode = false } }
                    } else {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
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
