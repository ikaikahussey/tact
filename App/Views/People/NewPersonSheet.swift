import SwiftUI

/// Adds a person: their name, and the tile they will get — a pattern (a
/// built-in motif or a saved FatBits pattern) and a colour, chosen from
/// rows of swatches under a preview. The rows start on a look drawn from a
/// fresh seed, so Add with nothing chosen gives the same kind of tile a
/// person always got.
struct NewPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TactStore
    /// Called with the trimmed name, the colour, the pattern and, when a
    /// saved pattern was chosen, its bits, on Add.
    let onAdd: (String, Int, TilePattern, FatBits?) -> Void

    @State private var name = ""
    @State private var colorIndex: Int
    @State private var pattern: TilePattern
    /// The saved pattern chosen instead of a built-in one, if any.
    @State private var savedPattern: SavedPattern?
    @FocusState private var nameFocused: Bool

    init(onAdd: @escaping (String, Int, TilePattern, FatBits?) -> Void) {
        self.onAdd = onAdd
        let seed = Int.random(in: 0..<360)
        _colorIndex = State(initialValue: TileArt(seed: seed).colorIndex)
        _pattern = State(initialValue: TilePattern(seed: seed))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
                Section("Tile") {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            TileShades(colorIndex: colorIndex).pale
                            TileMotifView(bits: savedPattern?.bits, pattern: pattern, colorIndex: colorIndex)
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("\(TilePalette.name(colorIndex)) \(savedPattern?.name ?? pattern.title) tile")
                        VStack(alignment: .leading, spacing: 10) {
                            patternRow
                            colorRow
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private var patternRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TilePattern.allCases, id: \.self) { option in
                    let isSelected = savedPattern == nil && option == pattern
                    patternSwatch(isSelected: isSelected, label: option.title) {
                        pattern = option
                        savedPattern = nil
                    } content: {
                        TilePatternView(pattern: option, colorIndex: colorIndex)
                    }
                }
                if !store.patternLibrary.isEmpty {
                    Divider().frame(height: 28)
                    ForEach(store.patternLibrary.patterns) { saved in
                        let isSelected = savedPattern?.id == saved.id
                        patternSwatch(isSelected: isSelected, label: "Saved pattern \(saved.name)") {
                            savedPattern = saved
                        } content: {
                            FatBitsView(bits: saved.bits, colorIndex: colorIndex)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern, \(savedPattern?.name ?? pattern.title)")
    }

    private func patternSwatch<Content: View>(isSelected: Bool, label: String, action: @escaping () -> Void,
                                              @ViewBuilder content: () -> Content) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            content()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TilePalette.menuOrder, id: \.self) { index in
                    let isSelected = index == colorIndex
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        colorIndex = index
                    } label: {
                        Circle()
                            .fill(TilePalette.color(index))
                            .frame(width: 28, height: 28)
                            .padding(3)
                            .overlay(Circle()
                                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2.5))
                            .frame(minWidth: 40, minHeight: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TilePalette.name(index).capitalized)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color, \(TilePalette.name(colorIndex))")
    }

    private func add() {
        guard !trimmedName.isEmpty else { return }
        onAdd(trimmedName, colorIndex, pattern, savedPattern?.bits)
        dismiss()
    }
}
