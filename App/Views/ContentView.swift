import SwiftUI

struct ContentView: View {
    @AppStorage(AppPalette.storageKey) private var paletteKind: AppPalette.Kind = .classic
    @AppStorage(CustomPalette.storageKey) private var customColors = Data()

    /// The chosen palette with the user's own colours, so the app redraws
    /// as either changes.
    private var palette: AppPalette { AppPalette(kind: paletteKind, customData: customColors) }

    var body: some View {
        PeopleRootView()
            .font(.tact(.body))
            .tint(palette.accent)
            .environment(\.appPalette, palette)
    }
}
