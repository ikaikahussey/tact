import SwiftUI

/// The colours of the palette the user makes themself in Settings: one for
/// each of the twelve tile colours, in `TilePalette` order, and the accent
/// for buttons and highlights. Kept in `UserDefaults` as JSON beside the
/// chosen palette, so it survives switching to a preset and back.
struct CustomPalette: Codable, Hashable {
    /// A colour as its sRGB components, 0 to 1, so it can be saved.
    struct RGB: Codable, Hashable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = min(max(red, 0), 1)
            self.green = min(max(green, 0), 1)
            self.blue = min(max(blue, 0), 1)
        }

        /// The colour's components as they resolve in light mode.
        init(_ color: Color) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                .getRed(&r, green: &g, blue: &b, alpha: &a)
            self.init(red: r, green: g, blue: b)
        }

        var color: Color { Color(red: red, green: green, blue: blue) }

        /// Relative luminance, 0 for black to 1 for white.
        var luminance: Double {
            func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        /// Symbols and text drawn on this colour: black on a light one,
        /// white on a dark one.
        var onTop: Color {
            luminance > 0.4 ? .black : .white
        }
    }

    static let storageKey = "customPalette"

    /// The tile colours, `TileArt.colorCount` of them in `TilePalette` order.
    var tiles: [RGB]
    var accent: RGB

    /// The Classic tile colours, to start from, with the Classic blue as the
    /// accent: Classic's own accent is black in light mode and white in dark,
    /// which one fixed colour can't be. Built from the colour table directly
    /// rather than through `AppPalette.classic`, whose default colours are
    /// these.
    static let standard = CustomPalette(tiles: TilePalette.colors.map(RGB.init),
                                        accent: RGB(TilePalette.colors[5]))

    init(tiles: [RGB], accent: RGB) {
        self.tiles = Self.fitted(tiles)
        self.accent = accent
    }

    /// A copy of a preset's colours, ready to be changed.
    init(from preset: AppPalette) {
        self.init(tiles: (0..<TileArt.colorCount).map { RGB(preset.tileColor($0)) },
                  accent: RGB(preset.accent))
    }

    /// Brings a saved list to the full count: one saved with fewer colours
    /// (an older build, or a hand-edited file) takes the Classic colours for
    /// the rest, and extra entries are dropped.
    private static func fitted(_ tiles: [RGB]) -> [RGB] {
        var fitted = Array(tiles.prefix(TileArt.colorCount))
        while fitted.count < TileArt.colorCount {
            fitted.append(RGB(TilePalette.colors[fitted.count]))
        }
        return fitted
    }

    private enum CodingKeys: String, CodingKey { case tiles, accent }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(tiles: try container.decodeIfPresent([RGB].self, forKey: .tiles) ?? [],
                  accent: try container.decodeIfPresent(RGB.self, forKey: .accent) ?? Self.standard.accent)
    }

    /// Symbols and text on the accent: white on a dark accent, black on a
    /// light one.
    var onAccent: Color { accent.onTop }

    // MARK: Storage

    /// The saved colours, or the Classic ones when none are saved yet.
    init(data: Data) {
        self = (try? JSONDecoder().decode(CustomPalette.self, from: data)) ?? .standard
    }

    var data: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func load(from defaults: UserDefaults = .standard) -> CustomPalette {
        defaults.data(forKey: storageKey).map(CustomPalette.init(data:)) ?? .standard
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(data, forKey: Self.storageKey)
    }
}
