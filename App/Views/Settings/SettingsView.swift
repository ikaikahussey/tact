import SwiftUI

/// Layout choice, game settings, export and about information.
struct SettingsView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                Section("Art Puzzle") {
                    NavigationLink {
                        ArtSettingsView()
                    } label: {
                        LabeledContent("Puzzle Picture",
                                       value: store.settings.artSettings.imageData == nil ? "Default" : "Your Photo")
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
