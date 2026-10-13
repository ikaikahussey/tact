import SwiftUI

/// A sliding puzzle whose tiles are slices of one photo, one tile per person.
struct ArtPuzzleView: View {
    @EnvironmentObject private var store: TactStore
    @State private var puzzle: SlidingPuzzle?
    @State private var showingSettings = false

    private let columns = ArtImageCache.columns
    private var tileIDs: [UUID] { store.people.map(\.id) }

    var body: some View {
        Group {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Add people, then choose a photo to slice into one tile per person.")
                }
            } else if let imageData = store.settings.artSettings.imageData, let puzzle {
                board(imageData: imageData, puzzle: puzzle)
            } else {
                ContentUnavailableView {
                    Label("No Puzzle Photo", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Choose a photo to slice into one tile per person.")
                } actions: {
                    Button("Choose Photo") { showingSettings = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(Color.tactBackground)
        .onAppear(perform: resetIfNeeded)
        .onChange(of: tileIDs) { _, _ in reset() }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                ArtSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    private func board(imageData: Data, puzzle: SlidingPuzzle) -> some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(squareSize), spacing: 1), count: columns), spacing: 1) {
                        ForEach(Array(puzzle.slots.enumerated()), id: \.element) { slot, tileID in
                            if let tileID,
                               let index = tileIDs.firstIndex(of: tileID),
                               let tile = ArtImageCache.shared.tile(for: imageData, index: index, tileCount: tileIDs.count) {
                                Button { tap(slot) } label: {
                                    Image(uiImage: tile)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: squareSize, height: squareSize)
                                        .clipped()
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(store.people[index].name)
                                .accessibilityHint("Slides toward the empty space")
                            } else {
                                Color.tactTileGray
                                    .opacity(tileID == nil ? 0.5 : 1)
                                    .frame(width: squareSize, height: squareSize)
                                    .accessibilityHidden(true)
                            }
                        }
                    }

                    HStack {
                        if puzzle.isSolved {
                            Label("Solved", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                        Button("Shuffle", systemImage: "shuffle", action: shuffle)
                            .buttonStyle(.bordered)
                        Button("Photo", systemImage: "photo") { showingSettings = true }
                            .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func resetIfNeeded() {
        if puzzle == nil || puzzle?.solvedOrder != tileIDs { reset() }
    }

    private func reset() {
        puzzle = SlidingPuzzle(tileIDs: tileIDs, columns: columns)
    }

    private func tap(_ slot: Int) {
        guard puzzle?.run(from: slot).isEmpty == false else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            _ = puzzle?.tap(slot)
        }
    }

    private func shuffle() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            puzzle?.shuffle()
        }
    }
}
