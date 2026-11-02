import SwiftUI

/// Colour palette, puzzle picture, export, backup and about information.
struct SettingsView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPalette.storageKey) private var paletteKind: AppPalette.Kind = .classic
    @AppStorage(CustomPalette.storageKey) private var customColors = Data()
    @AppStorage(AppPalette.monochromeAccentKey) private var monochromeAccentData = Data()

    private var customPalette: AppPalette { AppPalette(kind: .custom, customData: customColors) }

    private var monochromeAccent: CustomPalette.RGB? {
        get { AppPalette.monochromeAccent(data: monochromeAccentData) }
        nonmutating set { monochromeAccentData = AppPalette.monochromeAccentData(newValue) }
    }

    /// Monochrome with its chosen accent, so its swatch rings in that colour.
    private var monochromePalette: AppPalette { AppPalette(.monochrome, monochromeAccent: monochromeAccent) }

    /// The palettes Settings offers, in order: the presets, with the user's
    /// choices on Monochrome and Custom.
    private var options: [AppPalette] {
        AppPalette.presets.map { $0.isMonochrome ? monochromePalette : $0 } + [customPalette]
    }
    @AppStorage(GameSounds.enabledKey) private var gameSoundsOn = true
    @AppStorage(DittyPlayer.playOnOpenKey) private var dittyOnOpen = DittyPlayer.playsOnOpen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(options) { option in
                                    Button { paletteKind = option.kind } label: {
                                        VStack(spacing: 6) {
                                            PaletteSwatch(palette: option, isSelected: option.kind == paletteKind)
                                            Text(option.title)
                                                .font(.tact(.caption))
                                                .foregroundStyle(option.kind == paletteKind ? Color.primary : Color.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .frame(width: 64)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(option.title)
                                    .accessibilityAddTraits(option.kind == paletteKind ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        // Bring the chosen palette into view; Custom sits past the edge.
                        .onAppear { proxy.scrollTo(paletteKind.rawValue, anchor: .center) }
                    }
                    if paletteKind == .monochrome {
                        monochromeAccentRow
                    }
                    NavigationLink {
                        CustomPaletteView()
                    } label: {
                        LabeledContent("Custom Colors", value: paletteKind == .custom ? "In Use" : "")
                    }
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Changes the colors of everyone's tiles and the app's buttons. Monochrome is one bit: ink on the page, with an accent of your choosing for the buttons. Custom Colors are your own: pick each tile color and the accent.")
                }

                Section {
                    NavigationLink {
                        SoundSettingsView()
                    } label: {
                        LabeledContent("Sound", value: gameSoundsOn ? "On" : "Off")
                    }
                    NavigationLink {
                        ArtSettingsView()
                    } label: {
                        LabeledContent("Puzzle Picture",
                                       value: store.settings.artSettings.imageData == nil ? "Default" : "Your Photo")
                    }
                } header: {
                    Text("Games")
                }

                Section {
                    Toggle("Play Ditty When Opening a Person", isOn: $dittyOnOpen)
                        .disabled(!gameSoundsOn)
                } header: {
                    Text("Ditties")
                } footer: {
                    Text("Everyone has a few notes on the Simon synth that stand for them. Record one on a person's page. Ditties also play from the Play Ditty action on tiles and in the list, and follow the Sound settings and the silent switch.")
                }

                Section {
                    ShareLink(item: store.outline()) {
                        Label("Export Outline", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Shares a plain-text summary of everyone and their notes.")
                }

                Section {
                    LabeledContent("iCloud Backup", value: backupStatusText)
                } footer: {
                    Text(backupFooter)
                }

                Section("About") {
                    TactLogo(height: 28)
                        .padding(.vertical, 4)
                    LabeledContent("Version", value: Bundle.main.displayVersion)
                    Link(destination: TactLinks.privacyPolicy) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.tact(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint("Opens in Safari")
                    Text("Tact keeps your data on this device and, when iCloud is on, in your own iCloud account. Nothing is sent anywhere else unless you export it.")
                        .font(.tact(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Monochrome's accent: a colour picker, and a way back to the ink once
    /// a colour is chosen.
    private var monochromeAccentRow: some View {
        HStack {
            ColorPicker(selection: monochromeAccentBinding, supportsOpacity: false) {
                Label {
                    Text("Accent")
                } icon: {
                    Image(systemName: "checkmark")
                        .font(.tact(.caption).weight(.bold))
                        .foregroundStyle(monochromePalette.onAccent)
                        .frame(width: 28, height: 28)
                        .background(monochromePalette.accent, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            if monochromeAccent != nil {
                Button("Ink") {
                    UISelectionFeedbackGenerator().selectionChanged()
                    monochromeAccent = nil
                }
                .font(.tact(.footnote).weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityLabel("Use Ink for the Accent")
            }
        }
    }

    private var monochromeAccentBinding: Binding<Color> {
        Binding(
            get: { monochromeAccent?.color ?? AppPalette.ink },
            set: { monochromeAccent = CustomPalette.RGB($0) }
        )
    }

    private var backupStatusText: String {
        switch store.backupStatus {
        case .checking:    "Checking…"
        case .on:          "On"
        case .unavailable: "Off"
        case .failed:      "Not Restored"
        }
    }

    private var backupFooter: String {
        switch store.backupStatus {
        case .checking, .on:
            "Your people, notes and photos are copied to your iCloud account, so they come back if you delete and reinstall Tact."
        case .unavailable:
            "Sign in to iCloud and turn it on for Tact in the Settings app to keep your data if Tact is deleted."
        case .failed:
            "An earlier iCloud backup could not be downloaded. Tact will try again next time it opens."
        }
    }
}
