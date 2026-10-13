import Foundation

/// The state of a sliding-tile puzzle: every tile id plus one blank slot.
/// Tapping a tile in the blank's row or column slides the whole run of tiles
/// between them toward the blank.
struct SlidingPuzzle: Equatable {
    let columns: Int
    let solvedOrder: [UUID]
    private(set) var slots: [UUID?]

    init(tileIDs: [UUID], columns: Int = 4) {
        self.columns = max(1, columns)
        self.solvedOrder = tileIDs
        self.slots = tileIDs.map(Optional.some) + [nil]
    }

    var blankIndex: Int {
        slots.firstIndex { $0 == nil } ?? slots.count - 1
    }

    var isSolved: Bool {
        slots == solvedOrder.map(Optional.some) + [nil]
    }

    /// Slot indices that would move if `index` were tapped, ordered from the
    /// tapped slot toward the blank. Empty when the tap does nothing.
    func run(from index: Int) -> [Int] {
        guard slots.indices.contains(index), slots[index] != nil else { return [] }
        let blank = blankIndex
        let (tapRow, tapCol) = (index / columns, index % columns)
        let (blankRow, blankCol) = (blank / columns, blank % columns)

        if tapRow == blankRow {
            return tapCol < blankCol
                ? (tapCol..<blankCol).map { tapRow * columns + $0 }
                : ((blankCol + 1)...tapCol).map { tapRow * columns + $0 }.reversed()
        }
        if tapCol == blankCol {
            return tapRow < blankRow
                ? (tapRow..<blankRow).map { $0 * columns + tapCol }
                : ((blankRow + 1)...tapRow).map { $0 * columns + tapCol }.reversed()
        }
        return []
    }

    /// Slides tiles toward the blank. Returns `false` if nothing moved.
    @discardableResult
    mutating func tap(_ index: Int) -> Bool {
        let run = run(from: index)
        guard !run.isEmpty else { return false }
        let blank = blankIndex
        // Shift every tile in the run one step toward the blank; the tapped slot becomes blank.
        for (position, slot) in run.reversed().enumerated() {
            let destination = position == 0 ? blank : run.reversed()[position - 1]
            slots[destination] = slots[slot]
        }
        slots[run[0]] = nil
        return true
    }

    /// Slots adjacent to the blank that hold a tile.
    var movableNeighbors: [Int] {
        let blank = blankIndex
        let row = blank / columns, col = blank % columns
        var candidates: [Int] = []
        if col > 0 { candidates.append(blank - 1) }
        if col < columns - 1 { candidates.append(blank + 1) }
        if row > 0 { candidates.append(blank - columns) }
        candidates.append(blank + columns)
        return candidates.filter { slots.indices.contains($0) && slots[$0] != nil }
    }

    /// Scrambles with random legal moves, so the result is always solvable.
    mutating func shuffle<G: RandomNumberGenerator>(moves: Int = 300, using generator: inout G) {
        guard slots.count > 2 else { return }
        var previousBlank: Int? = nil
        for _ in 0..<moves {
            let options = movableNeighbors.filter { $0 != previousBlank }
            guard let choice = (options.isEmpty ? movableNeighbors : options).randomElement(using: &generator) else { return }
            previousBlank = blankIndex
            tap(choice)
        }
        if isSolved, let neighbor = movableNeighbors.first {
            tap(neighbor)
        }
    }

    mutating func shuffle(moves: Int = 300) {
        var generator = SystemRandomNumberGenerator()
        shuffle(moves: moves, using: &generator)
    }
}
