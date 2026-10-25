import SwiftUI

/// The People tab. Switches between Tiles (with its games on the back) and
/// the list, and hosts the shared "Add Person" and settings actions.
struct PeopleTabView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(PeopleLayout.storageKey) private var layout: PeopleLayout = .standard
    @AppStorage(PeopleGridContent.showingGamesKey) private var tilesShowingGames = false
    @AppStorage(TileGame.storageKey) private var tilesGameID = TileGame.all[0].id
    @State private var showingLayouts = false
    @State private var showingAddPerson = false
    @State private var showingSettings = false
    @State private var newPersonName = ""

    /// "People" with a caret: tapping it slides out the views as icons.
    private var header: some View {
        TabHeader("People") {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy) { showingLayouts.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showingLayouts ? 180 : 0))
                        .frame(width: 28, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(showingLayouts ? "Hide Views" : "Show Views")
                .accessibilityValue(layout.resolved.title)

                if showingLayouts {
                    HStack(spacing: 4) {
                        ForEach(PeopleLayout.available) { option in
                            layoutButton(option)
                        }
                    }
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                }
            }
            .buttonStyle(.plain)
            // Same height open or closed, centred on the title's capitals.
            .frame(height: 36)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 12 }
        }
    }

    private func layoutButton(_ option: PeopleLayout) -> some View {
        let isSelected = layout.resolved == option
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy) {
                layout = option
                showingLayouts = false
            }
        } label: {
            Image(systemName: option.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 36, height: 36)
                .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactTileGray.opacity(0.5)),
                            in: Circle())
        }
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .overlay(alignment: .trailing) {
                        if layout.resolved == .list && !store.people.isEmpty && !showingLayouts {
                            OutlineToggle()
                                .padding(.trailing, 20)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    }
                switch layout.resolved {
                case .list:
                    PeopleListContent()
                case .grid, .colors, .art, .tangram:
                    PeopleGridContent()
                case .flashcards:
                    FlashcardView()
                }
            }
            .background(Color.tactBackground)
            .onAppear {
                // The puzzle and Tangram used to be layouts; they are now games
                // on the back of Tiles.
                if let game = layout.formerGame {
                    tilesShowingGames = true
                    tilesGameID = game.id
                    layout = .grid
                }
            }
            .navigationTitle("People")
            .appTitleBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
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
        }
    }
}
