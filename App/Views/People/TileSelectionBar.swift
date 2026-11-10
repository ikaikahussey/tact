import SwiftUI

/// The bar that replaces the view switch while tiles are being selected:
/// how many are chosen, Select All or None, and the changes made to every
/// chosen tile at once — Color, Tile (a built-in pattern, a saved pattern,
/// or back to each person's own pattern), Rotate, Stack (group the chosen
/// tiles into one stack, or Unstack when the selection is one whole
/// stack), and Delete.
struct TileSelectionBar: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    @Environment(\.displayScale) private var displayScale
    @Binding var selection: Set<UUID>
    /// Everyone who can be selected: the people on the grid right now.
    let candidates: [UUID]
    let onDone: () -> Void

    @State private var confirmingDelete = false

    private var count: Int { selection.count }
    private var hasSelection: Bool { !selection.isEmpty }
    private var allSelected: Bool { !candidates.isEmpty && Set(candidates).isSubset(of: selection) }
    private var selectedPeople: [Person] { store.people.filter { selection.contains($0.id) } }
    /// The stack the selection is exactly, if it is one: Stack turns to Unstack.
    private var selectedStack: UUID? {
        TileLayout.stacks(for: store.people).first { Set($0.value) == selection }?.key
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(count == 0 ? "Select tiles" : count == 1 ? "1 tile selected" : "\(count) tiles selected")
                    .font(.tact(.subheadline).weight(.semibold))
                    .contentTransition(.numericText())
                Spacer()
                Button(allSelected ? "Select None" : "Select All") {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) {
                        selection = allSelected ? [] : Set(candidates)
                    }
                }
                .font(.tact(.subheadline))
                .disabled(candidates.isEmpty)
                Button("Done", action: onDone)
                    .font(.tact(.subheadline).weight(.semibold))
            }
            .padding(.horizontal, 4)
            HStack(spacing: 6) {
                if !palette.isMonochrome { colorMenu }
                tileMenu
                action("Rotate", systemImage: "rotate.right") {
                    store.updateTiles(forPersonIDs: selection) { $0.rotate() }
                }
                stackAction
                action("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .animation(.snappy, value: count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(count == 0 ? "Selecting tiles" : "\(count) tiles selected")
        .confirmationDialog(count == 1 ? "Delete \(selectedPeople.first?.name ?? "this person")?" : "Delete \(count) people?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(count == 1 ? "Delete" : "Delete \(count) People", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                withAnimation(.snappy) {
                    store.deletePeople(ids: selection)
                    selection = []
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notes linked only to these people are deleted too. Notes shared with anyone else are kept.")
        }
    }

    // MARK: Menus

    /// A colour for every chosen tile. The swatch shows the colour they
    /// share, or none when they differ.
    private var colorMenu: some View {
        let shared = Set(selectedPeople.map(\.tile.colorIndex))
        let current = shared.count == 1 ? shared.first : nil
        return Menu {
            ForEach(TilePalette.menuOrder, id: \.self) { index in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    store.updateTiles(forPersonIDs: selection) { $0.colorIndex = index }
                } label: {
                    Label { Text(TilePalette.name(index).capitalized) } icon: {
                        Image(uiImage: TilePalette.swatch(index))
                    }
                    if index == current { Image(systemName: "checkmark") }
                }
            }
        } label: {
            actionLabel("Color", systemImage: "paintpalette")
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
        .accessibilityLabel("Color")
        .accessibilityHint("Colors every selected tile")
    }

    /// A motif for every chosen tile: a built-in pattern, a saved FatBits
    /// pattern (each person keeps their own colour), or each person's own
    /// pattern again. Pictures are drawn in the colour the selection shares,
    /// or the palette's first colour when it mixes.
    private var tileMenu: some View {
        let shared = Set(selectedPeople.map(\.tile.colorIndex))
        let colorIndex = shared.count == 1 ? shared.first! : TilePalette.menuOrder[0]
        let available = store.availablePatterns()
        return Menu {
            ForEach(TilePattern.allCases, id: \.self) { pattern in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    store.updateTiles(forPersonIDs: selection) {
                        $0.pattern = pattern.rawValue
                        $0.showsPhoto = false
                        $0.revertToPattern()
                    }
                } label: {
                    Label { Text(pattern.title) } icon: {
                        Image(uiImage: TileMenuImage.motif(pattern: pattern, colorIndex: colorIndex, scale: displayScale))
                    }
                }
            }
            if !available.isEmpty {
                Divider()
                ForEach(available) { saved in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        store.applyPattern(id: saved.id, toPersonIDs: selection)
                    } label: {
                        Label { Text(saved.name) } icon: {
                            Image(uiImage: TileMenuImage.motif(bits: saved.bits, pattern: .cross, colorIndex: colorIndex, scale: displayScale))
                        }
                    }
                }
            }
            if selectedPeople.contains(where: { $0.tile.isFatBits }) {
                Divider()
                Button {
                    store.updateTiles(forPersonIDs: selection) { $0.revertToPattern() }
                } label: {
                    Label("Revert to Own Patterns", systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            actionLabel("Tile", systemImage: "square.on.square")
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
        .accessibilityLabel("Tile")
        .accessibilityHint("A pattern for every selected tile")
    }

    // MARK: Buttons

    /// Stack groups the chosen tiles into one; with one whole stack
    /// chosen it is Unstack, which lays them out again.
    @ViewBuilder
    private var stackAction: some View {
        if let stack = selectedStack {
            action("Unstack", systemImage: "square.stack.3d.up.slash") {
                store.unstack(id: stack)
            }
        } else {
            action("Stack", systemImage: "square.stack.3d.up", isEnabled: count > 1) {
                // A stack among them brings everyone in it.
                if let stack = store.stackTiles(personIDs: selection) {
                    selection = Set(TileLayout.stacks(for: store.people)[stack] ?? [])
                }
            }
        }
    }

    private func action(_ title: String, systemImage: String, role: ButtonRole? = nil, isEnabled: Bool? = nil,
                        perform: @escaping () -> Void) -> some View {
        let enabled: Bool = isEnabled ?? hasSelection
        return Button(role: role) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.snappy) { perform() }
        } label: {
            actionLabel(title, systemImage: systemImage, isEnabled: enabled)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityHint(enabled ? "\(title) every selected tile" : hasSelection ? "Select two or more tiles" : "Select tiles first")
    }

    private func actionLabel(_ title: String, systemImage: String, isEnabled: Bool? = nil) -> some View {
        let hasSelection: Bool = isEnabled ?? self.hasSelection
        return actionLabelBody(title, systemImage: systemImage, hasSelection: hasSelection)
    }

    private func actionLabelBody(_ title: String, systemImage: String, hasSelection: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.tact(.body).weight(.semibold))
            Text(title)
                .font(.tact(.caption2))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .foregroundStyle(hasSelection ? AnyShapeStyle(palette.accent) : AnyShapeStyle(.secondary))
        .background(Color.tactTileGray.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
