import SwiftUI

struct ContentView: View {
    @AppStorage(AppPalette.storageKey) private var paletteKind: AppPalette.Kind = .classic
    @AppStorage(CustomPalette.storageKey) private var customColors = Data()
    @AppStorage(AppPalette.monochromeAccentKey) private var monochromeAccent = Data()

    /// The chosen palette with the user's own colours and Monochrome's
    /// accent, so the app redraws as any of them changes.
    private var palette: AppPalette {
        AppPalette(kind: paletteKind, customData: customColors, monochromeAccentData: monochromeAccent)
    }

    var body: some View {
        PeopleRootView()
            .font(.tact(.body))
            .tint(palette.accent)
            .environment(\.appPalette, palette)
    }
}
