import SwiftUI

@main
struct TactApp: App {
    @StateObject private var store = TactStore(backup: CloudBackup.iCloud)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            // Make sure the latest edits are on disk before the app can be suspended.
            if phase != .active { store.flush(waitUntilDone: true) }
        }
    }
}
