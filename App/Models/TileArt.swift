import Foundation
import CoreGraphics

/// How a person's tile looks and where it sits on the Tiles canvas: a
/// square with the person's photo, or their geometric pattern
/// (`TilePattern`) turned in quarter turns in one of the palette colours.
/// Shapes belong to the Tangram canvas; tiles are always one square cell.
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
    /// A motif drawn in FatBits, shown in place of the pattern when set.
    /// `pattern` is kept underneath, so reverting brings the original back.
    var bits: FatBits?
    /// The stack the tile is grouped into, shared by every tile in it. A
    /// stack takes one cell on the canvas, with its first person (in list
    /// order) on top; tapping it opens the rest (`TileLayout.stacks`).
    var stack: UUID?
    /// The design chosen for the stack, kept the same on every tile in it
    /// so it stays when the top person leaves. `nil` shows the stack as
    /// its first four tiles, scaled down.
    var stackDesign: StackDesign?

    init(quarterTurns: Int = 0, colorIndex: Int = 0, cell: Int? = nil, pattern: Int? = nil,
         showsPhoto: Bool = true, bits: FatBits? = nil, stack: UUID? = nil, stackDesign: StackDesign? = nil) {
        self.quarterTurns = quarterTurns
        self.colorIndex = colorIndex
        self.cell = cell
        self.pattern = pattern
        self.showsPhoto = showsPhoto
        self.bits = bits
        self.stack = stack
        self.stackDesign = stackDesign
    }

    var isFatBits: Bool { bits != nil }

    /// Takes the FatBits motif off, so the tile shows its pattern again.
    mutating func revertToPattern() {
        bits = nil
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
    private enum CodingKeys: String, CodingKey { case quarterTurns, colorIndex, cell, pattern, showsPhoto, bits, stack, stackDesign }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quarterTurns = (try? container.decodeIfPresent(Int.self, forKey: .quarterTurns)) ?? nil ?? 0
        let color = (try? container.decodeIfPresent(Int.self, forKey: .colorIndex)) ?? nil ?? 0
        colorIndex = ((color % Self.colorCount) + Self.colorCount) % Self.colorCount
        let cell = (try? container.decodeIfPresent(Int.self, forKey: .cell)) ?? nil
        self.cell = cell.flatMap { $0 >= 0 ? $0 : nil }
        pattern = (try? container.decodeIfPresent(Int.self, forKey: .pattern)) ?? nil
        showsPhoto = (try? container.decodeIfPresent(Bool.self, forKey: .showsPhoto)) ?? nil ?? true
        bits = (try? container.decodeIfPresent(FatBits.self, forKey: .bits)) ?? nil
        stack = (try? container.decodeIfPresent(UUID.self, forKey: .stack)) ?? nil
        stackDesign = (try? container.decodeIfPresent(StackDesign.self, forKey: .stackDesign)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quarterTurns, forKey: .quarterTurns)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encodeIfPresent(cell, forKey: .cell)
        try container.encodeIfPresent(pattern, forKey: .pattern)
        try container.encode(showsPhoto, forKey: .showsPhoto)
        try container.encodeIfPresent(bits, forKey: .bits)
        try container.encodeIfPresent(stack, forKey: .stack)
        try container.encodeIfPresent(stackDesign, forKey: .stackDesign)
    }
}

/// A design chosen for a stack in place of its scaled-down tiles: a
/// built-in pattern, or a FatBits drawing when `bits` is set, in a palette
/// color.
struct StackDesign: Codable, Equatable, Hashable {
    /// Raw value of a `TilePattern`.
    var pattern: Int
    var colorIndex: Int
    var bits: FatBits?

    init(pattern: Int, colorIndex: Int, bits: FatBits? = nil) {
        self.pattern = pattern
        self.colorIndex = colorIndex
        self.bits = bits
    }
}

/// Where everyone's tile sits on the canvas.
enum TileLayout {
    static let columns = 4
    /// Gap between cells on the canvas.
    static let spacing: CGFloat = 1
    /// Largest side a full-size cell is drawn at. Every single-screen
    /// iPhone and the iPhone Duo's outer display fill four across below
    /// this; wider canvases, such as the Duo's inner display, keep the
    /// tiles at this size and centre the board instead of blowing it up.
    static let maxCellSide: CGFloat = 120

    /// Side of a full-size cell on a canvas `width` wide: four across,
    /// capped at `maxCellSide`, in whole points.
    static func cellSide(forWidth width: CGFloat) -> CGFloat {
        let fill = ((width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
        return max(0, min(fill, maxCellSide))
    }

    /// Width of the board when cells are `cellSide` across.
    static func boardWidth(cellSide: CGFloat) -> CGFloat {
        cellSide * CGFloat(columns) + spacing * CGFloat(columns - 1)
    }

    /// Leading inset that centres a board of `cellSide` cells on a canvas
    /// `width` wide. The grid and the games share it so pieces land on tiles.
    static func inset(forWidth width: CGFloat, cellSide: CGFloat) -> CGFloat {
        max(0, ((width - boardWidth(cellSide: cellSide)) / 2).rounded(.down))
    }

    /// Maps cells to people. People keep the cell they were placed in (the
    /// first to claim a cell wins); everyone else fills the lowest free cells
    /// in list order. Empty cells are gaps. A stack is one tile here: its
    /// top person stands for it, and the people under them have no cell.
    static func cells(for people: [Person]) -> [Int: UUID] {
        Dictionary(uniqueKeysWithValues: anchors(for: people).map { ($1, $0) })
    }

    static func anchors(for people: [Person]) -> [UUID: Int] {
        let covered = covered(for: people)
        let onBoard = covered.isEmpty ? people : people.filter { covered[$0.id] == nil }
        return GridPlacement.anchors(for: onBoard, cell: \.tile.cell, footprint: footprint(of:at:))
    }

    // MARK: Stacks

    /// The stacks on the canvas: each stack's people in list order, the
    /// first of them on top. A stack needs two people; one left alone with
    /// a stack id is an ordinary tile.
    static func stacks(for people: [Person]) -> [UUID: [UUID]] {
        var members: [UUID: [UUID]] = [:]
        for person in people {
            if let stack = person.tile.stack { members[stack, default: []].append(person.id) }
        }
        return members.filter { $0.value.count > 1 }
    }

    /// Everyone under the top tile of a stack, with the person on top of them.
    static func covered(for people: [Person]) -> [UUID: UUID] {
        var tops: [UUID: UUID] = [:]
        for members in stacks(for: people).values {
            for id in members.dropFirst() { tops[id] = members[0] }
        }
        return tops
    }

    /// The first `count` empty cells after `cell`, for tiles leaving a stack.
    static func freeCells(after cell: Int, count: Int, taken: Set<Int>) -> [Int] {
        var free: [Int] = []
        var next = cell
        while free.count < count {
            next += 1
            if !taken.contains(next) { free.append(next) }
        }
        return free
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
        let cells = anchors(for: people).values
        return Set(cells) == Set(0..<cells.count)
    }

    /// Where `ids` land when the one at `source` is dragged to `target` and
    /// the others follow by the same offset; nil when any of them would
    /// cross the side of the board or go above the top.
    static func shifted(_ ids: Set<UUID>, from source: Int, to target: Int, anchors: [UUID: Int]) -> [UUID: Int]? {
        let rowDelta = target / columns - source / columns
        let columnDelta = target % columns - source % columns
        var moved: [UUID: Int] = [:]
        for id in ids {
            guard let cell = anchors[id] else { continue }
            let column = cell % columns + columnDelta
            let row = cell / columns + rowDelta
            guard (0..<columns).contains(column), row >= 0 else { return nil }
            moved[id] = row * columns + column
        }
        return moved
    }

    /// Where everyone sits after the tile at its anchor is moved to
    /// `target`. An empty target just takes the tile. An occupied one makes
    /// room: the run of tiles from the target back toward the tile's old
    /// cell slides one step, into the nearest gap (or the cell the tile
    /// left). Nobody trades places.
    static func inserting(_ id: UUID, at target: Int, anchors: [UUID: Int]) -> [UUID: Int] {
        guard target >= 0, let source = anchors[id], source != target else { return anchors }
        var occupant: [Int: UUID] = [:]
        for (person, cell) in anchors where person != id { occupant[cell] = person }
        var moved = anchors
        moved[id] = target
        guard occupant[target] != nil else { return moved }
        let step = source < target ? -1 : 1
        var gap = target
        while gap != source, occupant[gap] != nil { gap += step }
        // Slide each tile in the run one cell toward the gap.
        var cell = gap - step
        while true {
            if let person = occupant[cell] { moved[person] = cell + step }
            if cell == target { break }
            cell -= step
        }
        return moved
    }

    /// Where everyone sits once `group` lands on its cells: anyone in the
    /// way is pushed forward to the next free cell, pushing whoever is
    /// there in turn. Nobody trades places, and the cells the group left
    /// stay empty.
    static func pushing(aside group: [UUID: Int], anchors: [UUID: Int]) -> [UUID: Int] {
        var moved = group
        var taken = Set(group.values)
        let others = anchors.filter { group[$0.key] == nil }.sorted { ($0.value, $0.key.uuidString) < ($1.value, $1.key.uuidString) }
        for (person, current) in others {
            var cell = current
            while taken.contains(cell) { cell += 1 }
            moved[person] = cell
            taken.insert(cell)
        }
        return moved
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
}

