import SwiftUI

/// Adds a person: their name, and the tile they will get — a pattern and
/// a colour, chosen from rows of swatches under a preview. The rows start
/// on a look drawn from a fresh seed, so Add with nothing chosen gives
/// the same kind of tile a person always got.
struct NewPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// Called with the trimmed name, the colour and the pattern on Add.
    let onAdd: (String, Int, TilePattern) -> Void

    @State private var name = ""
    @State private var colorIndex: Int
    @State private var pattern: TilePattern
    @FocusState private var nameFocused: Bool

    init(onAdd: @escaping (String, Int, TilePattern) -> Void) {
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
                            TilePatternView(pattern: pattern, colorIndex: colorIndex)
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("\(TilePalette.name(colorIndex)) \(pattern.title) tile")
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
                    let isSelected = option == pattern
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        pattern = option
                    } label: {
                        TilePatternView(pattern: option, colorIndex: colorIndex)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern, \(pattern.title)")
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
        onAdd(trimmedName, colorIndex, pattern)
        dismiss()
    }
}
