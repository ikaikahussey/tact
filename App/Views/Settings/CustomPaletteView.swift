import SwiftUI

/// Where the user makes their own palette: a colour for each of the twelve
/// tile colours and one for the accent, each behind a colour picker, with a
/// preview of the tiles at the top. Opening it puts the Custom palette in
/// use, so the picks show on the app itself as they are made. Start From
/// copies a preset's colours as a starting point.
struct CustomPaletteView: View {
    @AppStorage(AppPalette.storageKey) private var paletteKind: AppPalette.Kind = .classic
    @AppStorage(CustomPalette.storageKey) private var customColors = Data()

    private var colors: CustomPalette {
        get { CustomPalette(data: customColors) }
        nonmutating set { customColors = newValue.data }
    }

    private var palette: AppPalette { AppPalette(.custom, custom: colors) }

    var body: some View {
        Form {
            Section {
                preview
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                ForEach(TilePalette.menuOrder, id: \.self) { index in
                    ColorPicker(selection: tileBinding(index), supportsOpacity: false) {
                        Label {
                            Text(TilePalette.name(index).capitalized)
                        } icon: {
                            TileMotifView(bits: nil, pattern: TilePattern(seed: index), colorIndex: index)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .environment(\.appPalette, palette)
                        }
                    }
                }
            } header: {
                Text("Tiles")
            } footer: {
                Text("Each person's tile keeps its color name, so a coral tile stays coral whatever you make coral look like.")
            }

            Section {
                ColorPicker(selection: accentBinding, supportsOpacity: false) {
                    Label {
                        Text("Accent")
                    } icon: {
                        Image(systemName: "checkmark")
                            .font(.tact(.caption).weight(.bold))
                            .foregroundStyle(palette.onAccent)
                            .frame(width: 28, height: 28)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } header: {
                Text("Buttons")
            } footer: {
                Text("Buttons, selections and highlights. Text on it turns white or black to stay readable.")
            }

            Section {
                Menu {
                    ForEach(AppPalette.presets) { preset in
                        Button(preset.title) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            colors = CustomPalette(from: preset)
                        }
                    }
                } label: {
                    Label("Start From a Preset", systemImage: "paintpalette")
                }
                .accessibilityHint("Replaces every color with a preset's, to change from there.")
            }
        }
        .navigationTitle("Custom Colors")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { paletteKind = .custom }
    }

    /// Everyone's tile colours as a row of tiles, with the accent as a dot
    /// beneath, drawn in the palette being made.
    private var preview: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(TilePalette.menuOrder, id: \.self) { index in
                    TileMotifView(bits: nil, pattern: TilePattern(seed: index * 7 + 3), colorIndex: index)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .environment(\.appPalette, palette)
            Capsule()
                .fill(palette.accent)
                .frame(height: 6)
                .padding(.horizontal, 40)
        }
        .accessibilityElement()
        .accessibilityLabel("Preview of your colors")
    }

    private func tileBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { colors.tiles[index].color },
            set: { newColor in
                var updated = colors
                updated.tiles[index] = CustomPalette.RGB(newColor)
                colors = updated
            }
        )
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { colors.accent.color },
            set: { newColor in
                var updated = colors
                updated.accent = CustomPalette.RGB(newColor)
                colors = updated
            }
        )
    }
}
