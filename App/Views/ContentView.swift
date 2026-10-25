import SwiftUI

struct ContentView: View {
    @AppStorage(AppPalette.storageKey) private var palette: AppPalette = .classic

    var body: some View {
        PeopleRootView()
            .font(.tact(.body))
            .tint(palette.accent)
            .environment(\.appPalette, palette)
    }
}
