import Foundation

/// How the People tab presents the list of people.
enum PeopleLayout: String, CaseIterable, Identifiable, Codable {
    case list
    case grid
    case colors
    case flashcards
    case art

    static let storageKey = "peopleLayout"

    /// Layouts offered in Settings. Random Colors and Flashcards are kept for
    /// stored preferences but hidden until they are ready to ship.
    static let available: [PeopleLayout] = [.list, .grid, .art]

    /// The layout to show: hidden layouts fall back to the list.
    var resolved: PeopleLayout { Self.available.contains(self) ? self : .list }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:       return "List"
        case .grid:       return "Photo Grid"
        case .colors:     return "Random Colors"
        case .flashcards: return "Flashcards"
        case .art:        return "Art Puzzle"
        }
    }

    var systemImage: String {
        switch self {
        case .list:       return "list.bullet"
        case .grid:       return "square.grid.3x3"
        case .colors:     return "paintpalette"
        case .flashcards: return "rectangle.stack"
        case .art:        return "photo.on.rectangle"
        }
    }

    /// Layouts that show people as tappable squares in a 4-column grid.
    var isGrid: Bool { self == .grid || self == .colors }
}

enum ColorPalette: String, Codable, CaseIterable, Identifiable {
    case vibrant    = "Vibrant"
    case pastel     = "Pastel"
    case earth      = "Earth Tones"
    case ocean      = "Ocean"
    case sunset     = "Sunset"
    case neon       = "Neon"
    case monochrome = "Monochrome"

    var id: String { rawValue }
}

struct RandomColorGameSettings: Codable, Equatable {
    var palette: ColorPalette = .vibrant

    init(palette: ColorPalette = .vibrant) {
        self.palette = palette
    }

    private enum CodingKeys: String, CodingKey { case palette }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        palette = (try? container.decodeIfPresent(ColorPalette.self, forKey: .palette)) ?? nil ?? .vibrant
    }
}

struct ArtGameSettings: Codable, Equatable {
    /// JPEG data of the photo sliced into puzzle tiles. One copy for the whole app.
    var imageData: Data?

    init(imageData: Data? = nil) {
        self.imageData = imageData
    }

    private enum CodingKeys: String, CodingKey { case imageData }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageData = (try? container.decodeIfPresent(Data.self, forKey: .imageData)) ?? nil
    }
}

/// App-wide settings for the game-style layouts.
struct GameTypeSettings: Codable, Equatable {
    var randomColorSettings = RandomColorGameSettings()
    var artSettings = ArtGameSettings()

    init() {}

    private enum CodingKeys: String, CodingKey { case randomColorSettings, artSettings }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        randomColorSettings = (try? container.decodeIfPresent(RandomColorGameSettings.self, forKey: .randomColorSettings)) ?? nil
            ?? RandomColorGameSettings()
        artSettings = (try? container.decodeIfPresent(ArtGameSettings.self, forKey: .artSettings)) ?? nil
            ?? ArtGameSettings()
    }
}
