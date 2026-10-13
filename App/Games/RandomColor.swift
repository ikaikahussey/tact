import SwiftUI

/// Derives a colour from a person's seed so the same person always gets the
/// same colour within a palette.
enum RandomColor {
    struct HSB: Equatable {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    static func hsb(seed rawSeed: Int, palette: ColorPalette) -> HSB {
        let seed = abs(rawSeed)
        switch palette {
        case .vibrant:
            return HSB(hue: Double(seed * 37 % 360) / 360,
                       saturation: 0.6 + Double(seed * 17 % 40) / 100,
                       brightness: 0.5 + Double(seed * 23 % 40) / 100)
        case .pastel:
            return HSB(hue: Double(seed * 37 % 360) / 360,
                       saturation: 0.2 + Double(seed * 17 % 20) / 100,
                       brightness: 0.8 + Double(seed * 23 % 20) / 100)
        case .earth:
            let hues = [20, 30, 40, 50, 100, 120]
            return HSB(hue: Double(hues[seed % hues.count]) / 360,
                       saturation: 0.3 + Double(seed * 17 % 30) / 100,
                       brightness: 0.4 + Double(seed * 23 % 30) / 100)
        case .ocean:
            let hues = [180, 195, 210, 225, 240]
            return HSB(hue: Double(hues[seed % hues.count]) / 360,
                       saturation: 0.4 + Double(seed * 17 % 40) / 100,
                       brightness: 0.3 + Double(seed * 23 % 50) / 100)
        case .sunset:
            let hues = [0, 10, 20, 30, 40, 340, 350]
            return HSB(hue: Double(hues[seed % hues.count]) / 360,
                       saturation: 0.5 + Double(seed * 17 % 40) / 100,
                       brightness: 0.4 + Double(seed * 23 % 50) / 100)
        case .neon:
            let hues = [0, 60, 120, 180, 240, 300]
            return HSB(hue: Double(hues[seed % hues.count]) / 360,
                       saturation: 0.9 + Double(seed * 17 % 10) / 100,
                       brightness: 0.9 + Double(seed * 23 % 10) / 100)
        case .monochrome:
            return HSB(hue: 0, saturation: 0, brightness: 0.15 + Double(seed * 37 % 70) / 100)
        }
    }

    static func color(seed: Int, palette: ColorPalette) -> Color {
        let value = hsb(seed: seed, palette: palette)
        return Color(hue: value.hue, saturation: value.saturation, brightness: value.brightness)
    }
}
