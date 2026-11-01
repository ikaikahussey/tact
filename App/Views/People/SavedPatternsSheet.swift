import SwiftUI

/// The saved FatBits patterns as a list: each shown as a tile in a colour,
/// to rename, reorder, delete, or pick. Opened from the FatBits editor
/// (picking puts the pattern on the canvas) and from a person's Tile menu
/// (picking makes it their tile).
struct SavedPatternsSheet: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    /// The colour the patterns are shown in: the person's, or the editor's.
    let colorIndex: Int
    /// Called with the pattern tapped; the sheet then closes.
    var onPick: ((SavedPattern) -> Void)?

    @State private var renaming: SavedPattern?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.patternLibrary.isEmpty {
                    ContentUnavailableView("No Saved Patterns",
                                           systemImage: "square.on.square.dashed",
                                           description: Text("Draw a tile in FatBits and tap Save to keep it under a name for other people."))
                } else {
                    List {
                        ForEach(store.patternLibrary.patterns) { pattern in
                            row(pattern)
                        }
                        .onDelete { offsets in
                            for index in offsets { store.deletePattern(id: store.patternLibrary.patterns[index].id) }
                        }
                        .onMove { source, destination in
                            store.movePatterns(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
            }
            .navigationTitle("Saved Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if !store.patternLibrary.isEmpty {
                    ToolbarItem(placement: .primaryAction) { EditButton() }
                }
            }
            .alert("Rename Pattern", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                    .textInputAutocapitalization(.words)
                Button("Rename") {
                    if let renaming { store.renamePattern(id: renaming.id, to: newName) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
    }

    private func row(_ pattern: SavedPattern) -> some View {
        Button {
            if let onPick {
                UISelectionFeedbackGenerator().selectionChanged()
                onPick(pattern)
                dismiss()
            } else {
                beginRenaming(pattern)
            }
        } label: {
            HStack(spacing: 14) {
                FatBitsView(bits: pattern.bits, colorIndex: colorIndex)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(pattern.name)
                    .font(.tact(.body))
                    .foregroundStyle(.primary)
                Spacer()
                if store.people.contains(where: { $0.tile.bits == pattern.bits }) {
                    let count = store.people.filter { $0.tile.bits == pattern.bits }.count
                    Text(count == 1 ? "1 person" : "\(count) people")
                        .font(.tact(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button { beginRenaming(pattern) } label: { Label("Rename", systemImage: "pencil") }
                .tint(.blue)
        }
        .contextMenu {
            Button { beginRenaming(pattern) } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { store.deletePattern(id: pattern.id) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityLabel("\(pattern.name) pattern")
        .accessibilityHint(onPick == nil ? "Tap to rename. Swipe to delete." : "Tap to use. Swipe to rename or delete.")
    }

    private func beginRenaming(_ pattern: SavedPattern) {
        newName = pattern.name
        renaming = pattern
    }
}
