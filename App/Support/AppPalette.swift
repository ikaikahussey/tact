import SwiftUI

/// The app's colour scheme: the colours tiles are drawn in and the accent
/// used for buttons and highlights. Every preset keeps the twelve tile
/// colours in the same order and roughly the same hue, so a tile keeps its
/// colour name when the palette changes. The Custom palette is the user's
/// own: twelve tile colours and an accent picked in Settings, carried here
/// so views redraw as they are changed.
struct AppPalette: Hashable, Identifiable {
    enum Kind: String, CaseIterable {
        case classic
        case pastel
        case earthy
        case jewel
        case nineties
        case grayscale
        case custom
    }

    let kind: Kind
    /// The user's colours; only the Custom palette draws with them.
    var custom: CustomPalette

    init(_ kind: Kind, custom: CustomPalette = .standard) {
        self.kind = kind
        self.custom = custom
    }

    static let classic = AppPalette(.classic)
    static let pastel = AppPalette(.pastel)
    static let earthy = AppPalette(.earthy)
    static let jewel = AppPalette(.jewel)
    static let nineties = AppPalette(.nineties)
    static let grayscale = AppPalette(.grayscale)

    /// The built-in palettes, in the order Settings shows them.
    static let presets: [AppPalette] = Kind.allCases.filter { $0 != .custom }.map { AppPalette($0) }

    /// Where the chosen kind is kept; the custom colours sit beside it under
    /// `CustomPalette.storageKey`.
    static let storageKey = "appPalette"

    /// The palette chosen in Settings, for code that can't read the environment.
    static var current: AppPalette { load(from: .standard) }

    static func load(from defaults: UserDefaults) -> AppPalette {
        let kind = defaults.string(forKey: storageKey).flatMap(Kind.init(rawValue:)) ?? .classic
        return AppPalette(kind, custom: CustomPalette.load(from: defaults))
    }

    /// The palette as `@AppStorage` holds it: the kind and the custom
    /// colours' JSON.
    init(kind: Kind, customData: Data) {
        self.init(kind, custom: CustomPalette(data: customData))
    }

    var id: String { kind.rawValue }
    var isCustom: Bool { kind == .custom }

    var title: String {
        switch kind {
        case .classic: "Classic"
        case .pastel:  "Pastel"
        case .earthy:  "Earthy"
        case .jewel:   "Jewel"
        case .nineties: "Nineties"
        case .grayscale: "Grayscale"
        case .custom: "Custom"
        }
    }

    /// Buttons, selections and the tab bar. Dark enough for white symbols on top.
    var accent: Color {
        switch kind {
        // Named directly: `.tint(.accentColor)` falls back to system blue.
        case .classic: Color("AccentColor")
        case .pastel:  Color(red: 0.45, green: 0.38, blue: 0.72)
        case .earthy:  Color(red: 0.62, green: 0.36, blue: 0.22)
        case .jewel:   Color(red: 0.05, green: 0.45, blue: 0.47)
        case .nineties: Color(red: 0.58, green: 0.06, blue: 0.56)
        case .grayscale: Color(white: 0.22)
        case .custom: custom.accent.color
        }
    }

    /// Symbols and text drawn on the accent. Classic's accent is black in light
    /// mode and white in dark mode, so what sits on it flips the other way;
    /// the other presets' accents are dark enough for white in both, and the
    /// Custom palette goes by how light its accent is.
    var onAccent: Color {
        switch kind {
        case .classic: Color(uiColor: .systemBackground)
        case .custom: custom.onAccent
        default: .white
        }
    }

    /// The Nineties, colour by colour: fuchsia, turquoise, lime and the rest
    /// of the Trapper Keeper, in the classic hue order so names still fit.
    static let ninetiesColors: [Color] = [
        Color(red: 1.00, green: 0.40, blue: 0.26),  // coral: neon coral
        Color(red: 1.00, green: 0.56, blue: 0.00),  // amber: tangerine
        Color(red: 1.00, green: 0.88, blue: 0.00),  // yellow: highlighter
        Color(red: 0.45, green: 0.85, blue: 0.15),  // green: lime
        Color(red: 0.00, green: 0.76, blue: 0.70),  // teal: turquoise
        Color(red: 0.15, green: 0.40, blue: 0.95),  // blue: electric blue
        Color(red: 0.56, green: 0.22, blue: 0.92),  // violet: electric purple
        Color(red: 0.96, green: 0.13, blue: 0.75),  // pink: fuchsia
        Color(red: 0.95, green: 0.10, blue: 0.38),  // red: raspberry
        Color(red: 0.10, green: 0.82, blue: 0.95),  // sky: cyan
        Color(red: 0.78, green: 0.44, blue: 0.24),  // brown: terracotta
        Color(red: 0.58, green: 0.58, blue: 0.72),  // gray: lavender gray
    ]

    /// Tile colour `index`, made from the classic colour of the same hue.
    /// Grayscale spreads the colours over shades of gray in menu order, so
    /// neighbours in the colour menu stay told apart; the Nineties has its
    /// own colours outright, and Custom the user's.
    func tileColor(_ index: Int) -> Color {
        let classic = TilePalette.colors[index]
        switch kind {
        case .classic:
            return classic
        case .custom:
            return custom.tiles[index].color
        case .nineties:
            return Self.ninetiesColors[index]
        case .grayscale:
            let step = Double(TilePalette.menuOrder.firstIndex(of: index) ?? index)
            return Color(white: 0.28 + 0.52 * step / Double(TilePalette.menuOrder.count - 1))
        case .pastel, .earthy, .jewel:
            break
        }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(classic).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        switch kind {
        case .pastel:
            saturation *= 0.45
            brightness = brightness * 0.35 + 0.65
        case .earthy:
            saturation *= 0.55
            brightness *= 0.78
        case .jewel:
            saturation = min(1, saturation * 1.15)
            brightness *= 0.66
        default:
            break
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

extension AppPalette {
    /// The twelve tile colours in menu order, blended into one sweep.
    var gradient: LinearGradient {
        LinearGradient(colors: TilePalette.menuOrder.map(tileColor), startPoint: .leading, endPoint: .trailing)
    }
}

/// A palette as a disc of its colours, ringed when chosen.
struct PaletteSwatch: View {
    let palette: AppPalette
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(palette.gradient)
            .frame(width: 44, height: 44)
            .overlay {
                Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: isSelected ? 3 : 0)
            }
            .overlay {
                Circle().strokeBorder(palette.accent, lineWidth: isSelected ? 2.5 : 0)
                    .padding(-3)
            }
            .accessibilityHidden(true)
    }
}
