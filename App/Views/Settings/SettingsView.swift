import SwiftUI

/// Colour palette, puzzle picture, export, backup and about information.
struct SettingsView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPalette.storageKey) private var palette: AppPalette = .classic
    @AppStorage(GameSounds.enabledKey) private var gameSoundsOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(AppPalette.allCases) { option in
                            Button { palette = option } label: {
                                VStack(spacing: 6) {
                                    PaletteSwatch(palette: option, isSelected: option == palette)
                                    Text(option.title)
                                        .font(.tact(.caption))
                                        .foregroundStyle(option == palette ? Color.primary : Color.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(option == palette ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Changes the colors of everyone's tiles and the app's buttons.")
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
