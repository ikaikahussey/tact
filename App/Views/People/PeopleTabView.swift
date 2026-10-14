import SwiftUI

/// The People tab. Switches between the list and the Tiles grid, starts
/// games, and hosts the shared "Add Person" and settings actions.
struct PeopleTabView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var layout: PeopleLayout = .list
    @State private var showingAddPerson = false
    @State private var showingSettings = false
    @State private var newPersonName = ""
    @State private var gridMode: GridMode = .browse
    @State private var pendingGame: Game?
    @State private var unlockShortfall: Int?
    @State private var presentedGame: Game?

    /// "People" with a chevron: tapping opens the view-mode menu.
    private var header: some View {
        Menu {
            Picker("View", selection: $layout) {
                ForEach(PeopleLayout.available) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
            Section("Games") {
                ForEach(Game.allCases) { game in
                    Button { play(game) } label: {
                        // A second Text beside the Label becomes the menu item's subtitle.
                        Label(game.title, systemImage: game.systemImage)
                        if let shortfall = shortfall(for: game), shortfall > 0 {
                            Text("Locked · add \(shortfall) more \(shortfall == 1 ? "person" : "people")")
                        }
                    }
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
        .accessibilityHint("Changes how people are shown or starts a game")
    }

    /// How many more people a game needs, when known.
    private func shortfall(for game: Game) -> Int? {
        switch game {
        case .artPuzzle: return unlockShortfall
        case .tangram: return max(0, TangramGameView.piecesPerSet - store.people.count)
        }
    }

    private func play(_ game: Game) {
        if game.playsInTiles {
            layout = .grid
            pendingGame = game
        } else {
            presentedGame = game
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                switch layout.resolved {
                case .list:
                    PeopleListContent()
                case .grid, .art:
                    PeopleGridContent(tileStyle: .tangram, mode: $gridMode, pendingGame: $pendingGame,
                                      unlockShortfall: $unlockShortfall) { showingAddPerson = true }
                case .colors:
                    PeopleGridContent(tileStyle: .color(store.settings.randomColorSettings.palette),
                                      mode: $gridMode, pendingGame: $pendingGame,
                                      unlockShortfall: $unlockShortfall) { showingAddPerson = true }
                case .flashcards:
                    FlashcardView()
                }
            }
            .background(Color.tactBackground)
            .navigationTitle("People")
            .appTitleBar()
            .toolbar {
                if gridMode == .reorder {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { withAnimation { gridMode = .browse } }
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
            .navigationDestination(item: $presentedGame) { game in
                switch game {
                case .tangram: TangramGameView()
                case .artPuzzle: EmptyView()
                }
            }
            .onChange(of: layout) { _, _ in gridMode = .browse }
            .onAppear {
                // The Art Puzzle used to be its own layout; it now lives in Tiles.
                if layout == .art { layout = .grid }
            }
        }
    }
}
