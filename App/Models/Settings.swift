import Foundation

/// How the People tab presents the list of people.
enum PeopleLayout: String, CaseIterable, Identifiable, Codable {
    case list
    case grid
    case colors
    case flashcards
    case art
    case tangram

    static let storageKey = "peopleLayout"

    /// Layouts offered in the People menu. Random Colors and Flashcards are
    /// kept for stored preferences but hidden until they are ready to ship.
    static let available: [PeopleLayout] = [.list, .grid, .tangram]

    /// The layout to show: the old Art Puzzle layout opens the Tiles canvas,
    /// other hidden layouts fall back to the list.
    var resolved: PeopleLayout {
        if self == .art { return .grid }
        return Self.available.contains(self) ? self : .list
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:       return "List"
        case .grid:       return "Tiles"
        case .colors:     return "Random Colors"
        case .flashcards: return "Flashcards"
        case .art:        return "Art Puzzle"
        case .tangram:    return "Tangram"
        }
    }

    var systemImage: String {
        switch self {
        case .list:       return "list.bullet"
        case .grid:       return "square.grid.3x3"
        case .colors:     return "paintpalette"
        case .flashcards: return "rectangle.stack"
        case .art:        return "photo.on.rectangle"
        case .tangram:    return "square.split.diagonal.2x2"
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

/// Settings for the retired Art Puzzle. Kept so older settings files still
/// decode (unknown keys, such as the old puzzle photo, are ignored).
struct ArtGameSettings: Codable, Equatable {}

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

/// How the Notes tab arranges notes.
enum NotesGrouping: String, CaseIterable, Identifiable, Codable {
    case recent
    case person

    static let storageKey = "notesGrouping"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Most Recent"
        case .person: return "By Person"
        }
    }

    var systemImage: String {
        switch self {
        case .recent: return "clock"
        case .person: return "person.2"
        }
    }
}
