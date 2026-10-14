import Foundation

/// How a person's tile looks and where it sits on the Tiles canvas: a filled
/// square or a right-angle triangle, turned in quarter turns, in one of the
/// palette colours. Tapping a tile turns it and moves to the next colour.
struct TileArt: Codable, Equatable, Hashable {
    enum Shape: String, Codable {
        case square
        case triangle
    }

    /// Number of colours in `TilePalette`; colour indexes wrap around it.
    static let colorCount = 8

    var shape: Shape
    /// Clockwise quarter turns. Not wrapped, so turning always animates forward.
    var quarterTurns: Int
    var colorIndex: Int
    /// Cell on the Tiles canvas, row by row from the top-left. `nil` until the
    /// tile has been placed; such tiles take the first free cells.
    var cell: Int?

    init(shape: Shape, quarterTurns: Int = 0, colorIndex: Int = 0, cell: Int? = nil) {
        self.shape = shape
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

    /// One tap: a quarter turn and the next colour.
    mutating func advance() {
        quarterTurns += 1
        colorIndex = (colorIndex + 1) % Self.colorCount
    }

    mutating func toggleShape() {
        shape = shape == .square ? .triangle : .square
    }

    private enum CodingKeys: String, CodingKey { case shape, quarterTurns, colorIndex, cell }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = (try? container.decodeIfPresent(Shape.self, forKey: .shape)) ?? nil ?? .triangle
        quarterTurns = (try? container.decodeIfPresent(Int.self, forKey: .quarterTurns)) ?? nil ?? 0
        let color = (try? container.decodeIfPresent(Int.self, forKey: .colorIndex)) ?? nil ?? 0
        colorIndex = ((color % Self.colorCount) + Self.colorCount) % Self.colorCount
        let cell = (try? container.decodeIfPresent(Int.self, forKey: .cell)) ?? nil
        self.cell = cell.flatMap { $0 >= 0 ? $0 : nil }
    }
}

/// Where everyone's tile sits on the canvas.
enum TileLayout {
    /// Maps cells to people. People keep the cell they were placed in (the
    /// first to claim a cell wins); everyone else fills the lowest free cells
    /// in list order. Empty cells are gaps.
    static func cells(for people: [Person]) -> [Int: UUID] {
        var layout: [Int: UUID] = [:]
        var unplaced: [Person] = []
        for person in people {
            if let cell = person.tile.cell, layout[cell] == nil {
                layout[cell] = person.id
            } else {
                unplaced.append(person)
            }
        }
        var next = 0
        for person in unplaced {
            while layout[next] != nil { next += 1 }
            layout[next] = person.id
        }
        return layout
    }
}
