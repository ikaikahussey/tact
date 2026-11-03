import XCTest
import SwiftUI
@testable import Tact

final class CustomPaletteTests: XCTestCase {
    private func components(_ color: Color) -> (CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testStartsFromTheClassicColoursAndCopiesPresets() {
        let standard = CustomPalette.standard
        XCTAssertEqual(standard.tiles.count, TileArt.colorCount)
        let (r, g, b) = components(standard.tiles[0].color)
        XCTAssertEqual(r, 0.91, accuracy: 0.01, "classic coral")
        XCTAssertEqual(g, 0.33, accuracy: 0.01)
        XCTAssertEqual(b, 0.24, accuracy: 0.01)

        let nineties = CustomPalette(from: .nineties)
        let pink = TilePalette.names.firstIndex(of: "pink")!
        XCTAssertEqual(nineties.tiles[pink].red, 0.96, accuracy: 0.01, "fuchsia copied")
        XCTAssertEqual(nineties.accent.red, 0.58, accuracy: 0.01)
    }

    func testMonochromeDrawsEverythingInAChosenInk() {
        let plain = AppPalette.monochrome
        XCTAssertNil(plain.monochromeInk)
        XCTAssertEqual(plain.ink, AppPalette.ink)
        XCTAssertEqual(plain.accent, AppPalette.ink)
        XCTAssertEqual(plain.onAccent, AppPalette.paper)

        let coral = CustomPalette.RGB(red: 0.9, green: 0.3, blue: 0.2)
        let red = AppPalette(.monochrome, monochromeInk: coral)
        XCTAssertEqual(red.ink, coral.color)
        XCTAssertEqual(red.accent, coral.color, "the accent is the ink")
        XCTAssertEqual(red.onAccent, .white, "a dark ink takes white on top")
        XCTAssertEqual(AppPalette(.monochrome, monochromeInk: CustomPalette.RGB(red: 1, green: 0.9, blue: 0.3)).onAccent, .black)
        for index in 0..<TileArt.colorCount {
            XCTAssertEqual(red.tileColor(index), coral.color, "every tile is the ink")
        }
        let shades = TileShades(colorIndex: 4, palette: red)
        XCTAssertEqual(shades.pale, .clear, "still one bit: the page shows through")
        XCTAssertEqual(shades.base, coral.color)
        XCTAssertEqual(shades.dark, coral.color)
        XCTAssertNotEqual(red, plain)

        // Saved as JSON beside the palette; nothing saved means black and white.
        let data = AppPalette.monochromeInkData(coral)
        XCTAssertEqual(AppPalette.monochromeInk(data: data), coral)
        XCTAssertEqual(AppPalette.monochromeInkData(nil), Data())
        XCTAssertNil(AppPalette.monochromeInk(data: Data()))
        XCTAssertNil(AppPalette.monochromeInk(data: Data("junk".utf8)))
        XCTAssertEqual(AppPalette(kind: .monochrome, customData: Data(), monochromeInkData: data).ink, coral.color)
        XCTAssertEqual(AppPalette(kind: .classic, customData: Data(), monochromeInkData: data).tileColor(0),
                       AppPalette.classic.tileColor(0), "only Monochrome wears it")

        let defaults = TestSupport.defaults()
        defaults.set("monochrome", forKey: AppPalette.storageKey)
        defaults.set(data, forKey: AppPalette.monochromeInkKey)
        XCTAssertEqual(AppPalette.load(from: defaults).ink, coral.color)
    }

    func testCustomPaletteDrawsWithItsOwnColours() {
        var colors = CustomPalette.standard
        colors.tiles[3] = CustomPalette.RGB(red: 0.1, green: 0.2, blue: 0.9)
        colors.accent = CustomPalette.RGB(red: 0.95, green: 0.9, blue: 0.2)
        let palette = AppPalette(.custom, custom: colors)

        XCTAssertEqual(palette.title, "Custom")
        XCTAssertTrue(palette.isCustom)
        let (r, g, b) = components(palette.tileColor(3))
        XCTAssertEqual(r, 0.1, accuracy: 0.01)
        XCTAssertEqual(g, 0.2, accuracy: 0.01)
        XCTAssertEqual(b, 0.9, accuracy: 0.01)
        XCTAssertEqual(components(TilePalette.color(3, in: palette)).2, 0.9, accuracy: 0.01)

        // A light accent takes black on top; a dark one takes white.
        XCTAssertEqual(palette.onAccent, .black)
        colors.accent = CustomPalette.RGB(red: 0.1, green: 0.1, blue: 0.4)
        XCTAssertEqual(AppPalette(.custom, custom: colors).onAccent, .white)

        // Two custom palettes with different colours are different palettes,
        // so the environment and image caches tell them apart.
        XCTAssertNotEqual(palette, AppPalette(.custom, custom: colors))
        XCTAssertEqual(AppPalette(.custom, custom: colors), AppPalette(.custom, custom: colors))
    }

    func testColoursRoundTripAndShortListsAreFilledIn() throws {
        var colors = CustomPalette.standard
        colors.tiles[11] = CustomPalette.RGB(red: 0.5, green: 0.25, blue: 0.75)
        let decoded = CustomPalette(data: colors.data)
        XCTAssertEqual(decoded, colors)

        let short = try JSONDecoder().decode(CustomPalette.self,
                                             from: Data(#"{"tiles":[{"red":1,"green":0,"blue":0}]}"#.utf8))
        XCTAssertEqual(short.tiles.count, TileArt.colorCount)
        XCTAssertEqual(short.tiles[0], CustomPalette.RGB(red: 1, green: 0, blue: 0))
        XCTAssertEqual(short.tiles[1], CustomPalette.standard.tiles[1], "the rest are classic")
        XCTAssertEqual(short.accent, CustomPalette.standard.accent)

        XCTAssertEqual(CustomPalette(data: Data("junk".utf8)), .standard)
        XCTAssertEqual(CustomPalette.RGB(red: 2, green: -1, blue: 0.5), CustomPalette.RGB(red: 1, green: 0, blue: 0.5), "clamped")
    }

    func testTheChosenPaletteLoadsWithItsCustomColours() {
        let defaults = UserDefaults(suiteName: "CustomPaletteTests.\(UUID().uuidString)")!
        XCTAssertEqual(AppPalette.load(from: defaults), .classic)

        var colors = CustomPalette.standard
        colors.accent = CustomPalette.RGB(red: 0.2, green: 0.6, blue: 0.3)
        colors.save(to: defaults)
        defaults.set(AppPalette.Kind.custom.rawValue, forKey: AppPalette.storageKey)

        let loaded = AppPalette.load(from: defaults)
        XCTAssertEqual(loaded.kind, .custom)
        XCTAssertEqual(loaded.custom, colors)
        XCTAssertEqual(AppPalette(kind: .custom, customData: colors.data), loaded)

        // Picking a preset keeps the custom colours for next time.
        defaults.set(AppPalette.Kind.pastel.rawValue, forKey: AppPalette.storageKey)
        XCTAssertEqual(AppPalette.load(from: defaults).kind, .pastel)
        XCTAssertEqual(CustomPalette.load(from: defaults), colors)
    }

    func testPresetsLeaveCustomOut() {
        XCTAssertEqual(AppPalette.presets.map(\.kind), [.classic, .pastel, .earthy, .jewel, .nineties, .monochrome])
        XCTAssertEqual(AppPalette.Kind.allCases.count, AppPalette.presets.count + 1)
    }
}
