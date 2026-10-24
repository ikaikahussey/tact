import Foundation

/// How a person's tile looks and where it sits on the Tiles canvas: a filled
/// square, right-angle triangle or circle, one cell or two-by-two, turned in
/// quarter turns, in one of the palette colours.
struct TileArt: Codable, Equatable, Hashable {
    enum Shape: String, Codable {
        case square
        case triangle
        case circle
    }

    /// The shapes offered in the tile menu: shape and size together.
    enum Style: CaseIterable, Identifiable {
        case triangle
        case square
        case largeTriangle
        case largeSquare
        case circle

        var id: Self { self }

        var shape: Shape {
            switch self {
            case .triangle, .largeTriangle: return .triangle
            case .square, .largeSquare:     return .square
            case .circle:                   return .circle
            }
        }

        var isLarge: Bool { self == .largeTriangle || self == .largeSquare }

        var title: String {
            switch self {
            case .triangle:      return "Triangle"
            case .square:        return "Square"
            case .largeTriangle: return "Large Triangle"
            case .largeSquare:   return "Large Square"
            case .circle:        return "Circle"
            }
        }
    }

    /// Number of colours in `TilePalette`; colour indexes wrap around it.
    static let colorCount = 12

    var shape: Shape
    /// Covers two-by-two cells instead of one.
    var isLarge: Bool
    /// Clockwise quarter turns. Not wrapped, so turning always animates forward.
    var quarterTurns: Int
    var colorIndex: Int
    /// Top-left cell on the Tiles canvas, row by row from the top-left. `nil`
    /// until the tile has been placed; such tiles take the first free cells.
    var cell: Int?

    init(shape: Shape, isLarge: Bool = false, quarterTurns: Int = 0, colorIndex: Int = 0, cell: Int? = nil) {
        self.shape = shape
        self.isLarge = isLarge
        self.quarterTurns = quarterTurns
        self.colorIndex = colorIndex
        self.cell = cell
    }

    /// The starting look for a person, derived from their seed so it is stable.
    init(seed rawSeed: Int) {
        let seed = abs(rawSeed)
        self.init(shape: seed % 3 == 1 ? .square : .triangle,
                  quarterTurns: seed % 4,
                  colorIndex: (seed / 4) % Self.colorCount)
    }

    /// Cells covered along each side.
    var span: Int { isLarge ? 2 : 1 }

    var style: Style {
        get {
            switch shape {
            case .triangle: return isLarge ? .largeTriangle : .triangle
            case .square:   return isLarge ? .largeSquare : .square
            case .circle:   return .circle
            }
        }
        set {
            shape = newValue.shape
            isLarge = newValue.isLarge
        }
    }

    mutating func rotate() {
        quarterTurns += 1
    }

    private enum CodingKeys: String, CodingKey { case shape, isLarge, quarterTurns, colorIndex, cell }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = (try? container.decodeIfPresent(Shape.self, forKey: .shape)) ?? nil ?? .triangle
        isLarge = (try? container.decodeIfPresent(Bool.self, forKey: .isLarge)) ?? nil ?? false
        quarterTurns = (try? container.decodeIfPresent(Int.self, forKey: .quarterTurns)) ?? nil ?? 0
        let color = (try? container.decodeIfPresent(Int.self, forKey: .colorIndex)) ?? nil ?? 0
        colorIndex = ((color % Self.colorCount) + Self.colorCount) % Self.colorCount
        let cell = (try? container.decodeIfPresent(Int.self, forKey: .cell)) ?? nil
        self.cell = cell.flatMap { $0 >= 0 ? $0 : nil }
    }
}

/// Where everyone's tile sits on the canvas.
enum TileLayout {
    static let columns = 4

    /// The cells a tile of `span` covers with its top-left at `anchor`, or
    /// `nil` when it would run off the right edge.
    static func covered(anchor: Int, span: Int) -> [Int]? {
        guard anchor >= 0, anchor % columns + span <= columns else { return nil }
        return (0..<span).flatMap { row in (0..<span).map { anchor + row * columns + $0 } }
    }

    /// `target`, moved left as far as needed for a tile of `span` to fit.
    static func fitting(_ target: Int, span: Int) -> Int {
        target - max(0, target % columns + span - columns)
    }

    /// Maps top-left cells to people. People keep the cell they were placed in
    /// (the first to claim a cell wins); everyone else fills the lowest cells
    /// where they fit, in list order. Empty cells are gaps.
    static func cells(for people: [Person]) -> [Int: UUID] {
        Dictionary(uniqueKeysWithValues: anchors(for: people).map { ($1, $0) })
    }

    static func anchors(for people: [Person]) -> [UUID: Int] {
        GridPlacement.anchors(for: people, cell: \.tile.cell, footprint: footprint(of:at:))
    }

    static func footprint(of person: Person, at anchor: Int) -> Set<Int>? {
        covered(anchor: anchor, span: person.tile.span).map(Set.init)
    }
}
