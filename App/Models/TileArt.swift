import Foundation

/// How a person's tile looks and where it sits on the Tiles canvas: a
/// square with the person's photo, or their geometric pattern
/// (`TilePattern`) turned in quarter turns in one of the palette colours.
struct TileArt: Codable, Equatable, Hashable {
    /// Number of colours in `TilePalette`; colour indexes wrap around it.
    static let colorCount = 12

    /// Clockwise quarter turns. Not wrapped, so turning always animates forward.
    var quarterTurns: Int
    var colorIndex: Int
    /// Cell on the Tiles canvas, row by row from the top-left. `nil` until the
    /// tile has been placed; such tiles take the first free cells.
    var cell: Int?
    /// Raw value of the chosen `TilePattern`. `nil` uses the one picked from
    /// the person's seed.
    var pattern: Int?
    /// Whether the tile shows the person's photo, when they have one, instead
    /// of the pattern.
    var showsPhoto: Bool

    init(quarterTurns: Int = 0, colorIndex: Int = 0, cell: Int? = nil, pattern: Int? = nil, showsPhoto: Bool = true) {
        self.quarterTurns = quarterTurns
        self.colorIndex = colorIndex
        self.cell = cell
        self.pattern = pattern
        self.showsPhoto = showsPhoto
    }

    /// The starting look for a person, derived from their seed so it is stable.
    init(seed rawSeed: Int) {
        let seed = abs(rawSeed)
        self.init(quarterTurns: seed % 4, colorIndex: (seed / 4) % Self.colorCount)
    }

    mutating func rotate() {
        quarterTurns += 1
    }

    // Tiles saved with a shape or size from earlier versions decode without them.
    private enum CodingKeys: String, CodingKey { case quarterTurns, colorIndex, cell, pattern, showsPhoto }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quarterTurns = (try? container.decodeIfPresent(Int.self, forKey: .quarterTurns)) ?? nil ?? 0
        let color = (try? container.decodeIfPresent(Int.self, forKey: .colorIndex)) ?? nil ?? 0
        colorIndex = ((color % Self.colorCount) + Self.colorCount) % Self.colorCount
        let cell = (try? container.decodeIfPresent(Int.self, forKey: .cell)) ?? nil
        self.cell = cell.flatMap { $0 >= 0 ? $0 : nil }
        pattern = (try? container.decodeIfPresent(Int.self, forKey: .pattern)) ?? nil
        showsPhoto = (try? container.decodeIfPresent(Bool.self, forKey: .showsPhoto)) ?? nil ?? true
    }
}

/// Where everyone's tile sits on the canvas.
enum TileLayout {
    static let columns = 4

    /// Maps cells to people. People keep the cell they were placed in (the
    /// first to claim a cell wins); everyone else fills the lowest free cells
    /// in list order. Empty cells are gaps.
    static func cells(for people: [Person]) -> [Int: UUID] {
        Dictionary(uniqueKeysWithValues: anchors(for: people).map { ($1, $0) })
    }

    static func anchors(for people: [Person]) -> [UUID: Int] {
        GridPlacement.anchors(for: people, cell: \.tile.cell, footprint: footprint(of:at:))
    }

    /// Everyone's tile in the first cells, in the order they sit now, so the
    /// gaps close up.
    static func compacted(_ people: [Person]) -> [UUID: Int] {
        let anchors = anchors(for: people)
        let order = anchors.sorted { $0.value < $1.value }.map(\.key)
        return Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
    }

    /// Whether the tiles already fill the first cells with no gaps.
    static func isCompact(_ people: [Person]) -> Bool {
        Set(anchors(for: people).values) == Set(0..<people.count)
    }

    static func footprint(of person: Person, at anchor: Int) -> Set<Int>? {
        anchor >= 0 ? [anchor] : nil
    }
}
/// Placement on the Tiles canvas: each person sits at
/// an anchor cell and covers a set of grid units there.
enum GridPlacement {
    /// People keep the anchor they were placed at (the first to claim the
    /// space wins); everyone else takes the lowest anchor where they fit, in
    /// list order.
    static func anchors(for people: [Person], cell: KeyPath<Person, Int?>,
                        footprint: (Person, Int) -> Set<Int>?) -> [UUID: Int] {
        var anchors: [UUID: Int] = [:]
        var taken = Set<Int>()
        var unplaced: [Person] = []
        for person in people {
            if let anchor = person[keyPath: cell], let units = footprint(person, anchor), taken.isDisjoint(with: units) {
                anchors[person.id] = anchor
                taken.formUnion(units)
            } else {
                unplaced.append(person)
            }
        }
        for person in unplaced {
            var next = 0
            while true {
                if let units = footprint(person, next), taken.isDisjoint(with: units) {
                    anchors[person.id] = next
                    taken.formUnion(units)
                    break
                }
                next += 1
            }
        }
        return anchors
    }

    /// Pins everyone to their current anchor (so filling gaps doesn't shuffle
    /// unplaced people around) and puts `id` at `anchor`. People it now
    /// overlaps move to `vacated` when they fit there, and otherwise to the
    /// first spot they fit.
    static func pinning(_ people: [Person], moving id: UUID, to anchor: Int, anchors: [UUID: Int], vacated: Int?,
                        cell: WritableKeyPath<Person, Int?>,
                        footprint: (Person, Int) -> Set<Int>?) -> [Person] {
        guard let moverIndex = people.firstIndex(where: { $0.id == id }) else { return people }
        var updated = people
        let moverUnits = footprint(updated[moverIndex], anchor) ?? []
        updated[moverIndex][keyPath: cell] = anchor
        var taken = moverUnits
        var displaced: [Int] = []
        for index in updated.indices where index != moverIndex {
            let current = anchors[updated[index].id]
            updated[index][keyPath: cell] = current
            let units = current.flatMap { footprint(updated[index], $0) } ?? []
            if moverUnits.isDisjoint(with: units) {
                taken.formUnion(units)
            } else {
                displaced.append(index)
            }
        }
        for index in displaced {
            if let vacated, let units = footprint(updated[index], vacated), taken.isDisjoint(with: units) {
                updated[index][keyPath: cell] = vacated
                taken.formUnion(units)
            } else {
                updated[index][keyPath: cell] = nil
            }
        }
        return updated
    }
}

