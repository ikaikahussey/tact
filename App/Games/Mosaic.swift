import Foundation

/// One square of a Mosaic: a tile motif in a palette colour, turned in
/// quarter turns. The same look as a person's tile (`TileArt` and
/// `TilePattern`), kept as plain numbers so a mosaic can be saved.
struct MosaicStamp: Codable, Equatable, Hashable {
    /// Raw value of a `TilePattern`, or `fatBitsPattern` for a stamp drawn
    /// in FatBits.
    var pattern: Int
    var colorIndex: Int
    /// Clockwise quarter turns, 0 to 3.
    var quarterTurns: Int
    /// The bitmap of a FatBits stamp; nil for a built-in motif.
    var bits: FatBits?

    /// The `pattern` of a FatBits stamp, outside every `TilePattern` raw value.
    static let fatBitsPattern = -1

    init(pattern: Int, colorIndex: Int, quarterTurns: Int = 0) {
        self.pattern = pattern
        self.colorIndex = colorIndex
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
        self.bits = nil
    }

    init(bits: FatBits, colorIndex: Int, quarterTurns: Int = 0) {
        self.pattern = Self.fatBitsPattern
        self.colorIndex = colorIndex
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
        self.bits = bits
    }

    var isFatBits: Bool { bits != nil }

    /// The stamp turned a quarter turn clockwise.
    var turned: MosaicStamp {
        var result = self
        result.quarterTurns = (quarterTurns + 1) % 4
        return result
    }

    /// The same stamp turned back to its first position.
    var unturned: MosaicStamp {
        var result = self
        result.quarterTurns = 0
        return result
    }

    /// Whether two stamps are the same motif and colour, whatever their turn.
    func sameLook(as other: MosaicStamp) -> Bool {
        pattern == other.pattern && colorIndex == other.colorIndex && bits == other.bits
    }
}

/// A Mosaic canvas: a grid of cells, each empty or holding a stamp. Because
/// every tile motif meets the middle of its edges with the same band, any
/// two stamps side by side join up, so the canvas reads as one quilt.
struct Mosaic: Codable, Equatable {
    let columns: Int
    private(set) var rows: Int
    private(set) var cells: [MosaicStamp?]

    init(columns: Int = 4, rows: Int = 4) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.cells = Array(repeating: nil, count: self.columns * self.rows)
    }

    var count: Int { cells.count }
    var isEmpty: Bool { !cells.contains { $0 != nil } }
    var filledCount: Int { cells.filter { $0 != nil }.count }

    subscript(index: Int) -> MosaicStamp? {
        cells.indices.contains(index) ? cells[index] : nil
    }

    /// Puts `stamp` in the cell. Stamping a cell that already shows the same
    /// motif and colour turns it a quarter turn instead, so repeated taps
    /// cycle through the four turns.
    mutating func stamp(_ stamp: MosaicStamp, at index: Int) {
        guard cells.indices.contains(index) else { return }
        if let current = cells[index], current.sameLook(as: stamp) {
            cells[index] = current.turned
        } else {
            cells[index] = stamp
        }
    }

    /// Puts `stamp` in the cell as it is, without turning what is there.
    mutating func place(_ stamp: MosaicStamp?, at index: Int) {
        guard cells.indices.contains(index) else { return }
        cells[index] = stamp
    }

    mutating func erase(at index: Int) {
        place(nil, at: index)
    }

    mutating func clear() {
        cells = Array(repeating: nil, count: count)
    }

    /// Replaces every cell showing `old`'s look with `new`, keeping each
    /// cell's turn.
    mutating func swap(_ old: MosaicStamp, for new: MosaicStamp) {
        for index in cells.indices {
            guard let current = cells[index], current.sameLook(as: old) else { continue }
            var replacement = new
            replacement.quarterTurns = current.quarterTurns
            cells[index] = replacement
        }
    }

    /// Empties every cell showing `stamp`'s look.
    mutating func remove(_ stamp: MosaicStamp) {
        for index in cells.indices where cells[index]?.sameLook(as: stamp) == true {
            cells[index] = nil
        }
    }

    /// Fills every cell with a random stamp from `palette`, each with a
    /// random turn. Does nothing with an empty palette.
    mutating func fill<G: RandomNumberGenerator>(from palette: [MosaicStamp], using generator: inout G) {
        guard !palette.isEmpty else { return }
        for index in cells.indices {
            var pick = palette[Int.random(in: 0..<palette.count, using: &generator)]
            pick.quarterTurns = Int.random(in: 0..<4, using: &generator)
            cells[index] = pick
        }
    }

    mutating func fill(from palette: [MosaicStamp]) {
        var generator = SystemRandomNumberGenerator()
        fill(from: palette, using: &generator)
    }

    /// The same canvas with `rows` rows: cells that still fit are kept, new
    /// rows start empty.
    func resized(rows newRows: Int) -> Mosaic {
        let target = max(1, newRows)
        guard target != rows else { return self }
        var result = Mosaic(columns: columns, rows: target)
        for index in 0..<min(count, result.count) {
            result.cells[index] = cells[index]
        }
        return result
    }

    // MARK: Saving

    static let storageKey = "mosaicCanvas"

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decoded(from data: Data?) -> Mosaic? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Mosaic.self, from: data)
    }
}

/// The stamps drawn in FatBits, kept on the palette strip beside everyone's
/// motifs. Saved on their own so they outlive a cleared canvas.
struct FatBitsShelf: Codable, Equatable {
    private(set) var stamps: [MosaicStamp] = []

    static let storageKey = "mosaicFatBits"
    static let limit = 24

    var count: Int { stamps.count }
    var isEmpty: Bool { stamps.isEmpty }
    var isFull: Bool { stamps.count >= Self.limit }

    /// Adds a stamp, unturned, unless the shelf is full or already holds
    /// that look. Returns the stamp as kept.
    @discardableResult
    mutating func add(_ stamp: MosaicStamp) -> MosaicStamp? {
        guard stamp.isFatBits, !isFull else { return nil }
        let kept = stamp.unturned
        if let existing = stamps.first(where: { $0.sameLook(as: kept) }) { return existing }
        stamps.append(kept)
        return kept
    }

    /// Replaces the stamp with `old`'s look by `new`, unturned. A new look
    /// that the shelf already holds is merged into that entry instead.
    mutating func replace(_ old: MosaicStamp, with new: MosaicStamp) {
        guard new.isFatBits, let index = stamps.firstIndex(where: { $0.sameLook(as: old) }) else { return }
        let kept = new.unturned
        if let other = stamps.firstIndex(where: { $0.sameLook(as: kept) }), other != index {
            stamps.remove(at: index)
        } else {
            stamps[index] = kept
        }
    }

    mutating func remove(_ stamp: MosaicStamp) {
        stamps.removeAll { $0.sameLook(as: stamp) }
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decoded(from data: Data?) -> FatBitsShelf? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FatBitsShelf.self, from: data)
    }
}
