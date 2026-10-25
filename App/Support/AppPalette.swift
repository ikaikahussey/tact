import SwiftUI

/// The app's colour scheme: the colours tiles are drawn in and the accent
/// used for buttons and highlights. Every palette keeps the twelve tile
/// colours in the same order and roughly the same hue, so a tile keeps its
/// colour name when the palette changes.
enum AppPalette: String, CaseIterable, Identifiable {
    case classic
    case pastel
    case earthy
    case jewel

    static let storageKey = "appPalette"

    /// The palette chosen in Settings, for code that can't read the environment.
    static var current: AppPalette {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppPalette.init(rawValue:)) ?? .classic
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .pastel:  "Pastel"
        case .earthy:  "Earthy"
        case .jewel:   "Jewel"
        }
    }

    /// Buttons, selections and the tab bar. Dark enough for white symbols on top.
    var accent: Color {
        switch self {
        // Named directly: `.tint(.accentColor)` falls back to system blue.
        case .classic: Color("AccentColor")
        case .pastel:  Color(red: 0.45, green: 0.38, blue: 0.72)
        case .earthy:  Color(red: 0.62, green: 0.36, blue: 0.22)
        case .jewel:   Color(red: 0.05, green: 0.45, blue: 0.47)
        }
    }

    /// Symbols and text drawn on the accent. Classic's accent is black in light
    /// mode and white in dark mode, so what sits on it flips the other way;
    /// the other accents are dark enough for white in both.
    var onAccent: Color {
        self == .classic ? Color(uiColor: .systemBackground) : .white
    }

    /// Tile colour `index`, made from the classic colour of the same hue.
    func tileColor(_ index: Int) -> Color {
        let classic = TilePalette.colors[index]
        guard self != .classic else { return classic }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(classic).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        switch self {
        case .classic:
            break
        case .pastel:
            saturation *= 0.45
            brightness = brightness * 0.35 + 0.65
        case .earthy:
            saturation *= 0.55
            brightness *= 0.78
        case .jewel:
            saturation = min(1, saturation * 1.15)
            brightness *= 0.66
        }
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette.classic
}

extension EnvironmentValues {
    /// The palette chosen in Settings. Views that draw tiles read it so they
    /// redraw when it changes.
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

/// The twelve tile colours of a palette in menu order, as a row of dots.
struct PaletteStrip: View {
    let palette: AppPalette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TilePalette.menuOrder, id: \.self) { index in
                Circle()
                    .fill(palette.tileColor(index))
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityHidden(true)
    }
}
