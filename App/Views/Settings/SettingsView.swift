import SwiftUI

/// Export and about information.
struct SettingsView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                    LabeledContent("Version", value: Bundle.main.displayVersion)
                    Text("Tact keeps your data on this device and, when iCloud is on, in your own iCloud account. Nothing is sent anywhere else unless you export it.")
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
