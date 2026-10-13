import SwiftUI

/// Layout choice, game settings, export and about information.
struct SettingsView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PeopleLayout.storageKey) private var layout: PeopleLayout = .list

    var body: some View {
        NavigationStack {
            Form {
                Section("People View") {
                    ForEach(PeopleLayout.allCases) { option in
                        Button {
                            layout = option
                            dismiss()
                        } label: {
                            HStack {
                                Label(option.title, systemImage: option.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if layout == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .accessibilityAddTraits(layout == option ? [.isSelected] : [])
                    }
                }

                Section("Random Colors") {
                    Picker("Palette", selection: $store.settings.randomColorSettings.palette) {
                        ForEach(ColorPalette.allCases) { palette in
                            Text(palette.rawValue).tag(palette)
                        }
                    }
                }

                Section("Art Puzzle") {
                    NavigationLink {
                        ArtSettingsView()
                    } label: {
                        LabeledContent("Puzzle Photo",
                                       value: store.settings.artSettings.imageData == nil ? "None" : "Chosen")
                    }
                }

                Section {
                    ShareLink(item: store.outline()) {
                        Label("Export Outline", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Shares a plain-text summary of everyone and their notes.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.displayVersion)
                    Text("Tact keeps everything on this device. Nothing is uploaded or shared unless you export it.")
                        .font(.footnote)
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
}
