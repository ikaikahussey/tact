import Foundation

/// The state of a Lights Out board: a grid of lights, each on or off.
/// Pressing a light toggles it and its four orthogonal neighbours. The
/// puzzle is solved when every light is off. Boards are scrambled by
/// pressing lights from the solved state, so they can always be solved
/// by pressing the same lights again.
struct LightsOut: Equatable {
    let columns: Int
    let rows: Int
    private(set) var lit: [Bool]
    private(set) var moveCount = 0

    init(columns: Int = 4, rows: Int = 4) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.lit = Array(repeating: false, count: self.columns * self.rows)
    }

    var count: Int { lit.count }
    var isSolved: Bool { !lit.contains(true) }
    var litCount: Int { lit.filter { $0 }.count }

    func isLit(_ index: Int) -> Bool {
        lit.indices.contains(index) && lit[index]
    }

    /// The light at `index` and its orthogonal neighbours that exist.
    func affected(by index: Int) -> [Int] {
        guard lit.indices.contains(index) else { return [] }
        let row = index / columns, column = index % columns
        var cells = [index]
        if column > 0 { cells.append(index - 1) }
        if column < columns - 1 { cells.append(index + 1) }
        if row > 0 { cells.append(index - columns) }
        if row < rows - 1 { cells.append(index + columns) }
        return cells
    }

    /// Toggles the light and its neighbours. Returns `false` for an index
    /// off the board.
    @discardableResult
    mutating func press(_ index: Int) -> Bool {
        let cells = affected(by: index)
        guard !cells.isEmpty else { return false }
        for cell in cells { lit[cell].toggle() }
        moveCount += 1
        return true
    }

    /// Scrambles from the solved state with `presses` distinct presses, so
    /// pressing those same lights again solves it. A scramble that comes out
    /// solved is retried, so a new game is never already won.
    mutating func scramble<G: RandomNumberGenerator>(presses: Int, using generator: inout G) {
        lit = Array(repeating: false, count: count)
        let wanted = min(max(1, presses), count)
        var chosen = Set<Int>()
        while chosen.count < wanted {
            chosen.insert(Int.random(in: 0..<count, using: &generator))
        }
        for cell in chosen { press(cell) }
        if isSolved {
            // Only possible on boards where a set of presses cancels out;
            // one more press always leaves something lit.
            press(Int.random(in: 0..<count, using: &generator))
        }
        moveCount = 0
    }

    mutating func scramble(presses: Int) {
        var generator = SystemRandomNumberGenerator()
        scramble(presses: presses, using: &generator)
    }

    var movesText: String { moveCount == 1 ? "1 move" : "\(moveCount) moves" }
}
