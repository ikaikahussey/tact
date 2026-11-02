import Foundation

/// Undo and redo for a value edited in steps: a stack of the states before
/// each edit, and one of the states undone, so a stroke in FatBits or a
/// stamp on the Mosaic can be taken back and put back. The editor keeps
/// the live value; this keeps the past. `record` is called with the value
/// as it stands before an edit; `undo` and `redo` take the live value and
/// hand back the one to show instead.
struct EditHistory<Value: Equatable>: Equatable {
    /// How many steps are kept. Beyond this the oldest is dropped.
    static var defaultLimit: Int { 100 }

    private(set) var undoStack: [Value] = []
    private(set) var redoStack: [Value] = []
    let limit: Int

    init(limit: Int = EditHistory.defaultLimit) {
        self.limit = max(1, limit)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Keeps `value`, the state before an edit about to be made. Anything
    /// undone is forgotten: a new edit starts a new future. Recording the
    /// same state twice in a row keeps it once, so a tool that changes
    /// nothing leaves no empty step.
    mutating func record(_ value: Value) {
        redoStack = []
        if undoStack.last == value { return }
        undoStack.append(value)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
    }

    /// Steps back: returns the state before the last edit, keeping
    /// `current` for redo. Nil when there is nothing to undo.
    mutating func undo(current: Value) -> Value? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    /// Steps forward again: returns the state last undone, keeping
    /// `current` for undo. Nil when there is nothing to redo.
    mutating func redo(current: Value) -> Value? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    mutating func clear() {
        undoStack = []
        redoStack = []
    }
}
