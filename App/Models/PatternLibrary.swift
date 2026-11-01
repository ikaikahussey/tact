import Foundation

/// A FatBits drawing kept under a name, so the same tile can be given to
/// other people. The bits carry no colour: a saved pattern takes the colour
/// of whoever wears it, as the built-in motifs do.
struct SavedPattern: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var bits: FatBits

    init(id: UUID = UUID(), name: String, bits: FatBits) {
        self.id = id
        self.name = SavedPattern.cleaned(name)
        self.bits = bits
    }

    /// Names are trimmed; an empty one becomes "Pattern".
    static func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pattern" : String(trimmed.prefix(40))
    }

    private enum CodingKeys: String, CodingKey { case id, name, bits }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: (try? container.decode(UUID.self, forKey: .id)) ?? UUID(),
                  name: (try? container.decode(String.self, forKey: .name)) ?? "",
                  bits: try container.decode(FatBits.self, forKey: .bits))
    }
}

/// The named FatBits patterns saved for reuse, in the order they were
/// saved. Kept with the settings, so they are backed up with everything
/// else and shared by the person page, the New Person sheet and the
/// FatBits editor.
struct PatternLibrary: Codable, Equatable {
    private(set) var patterns: [SavedPattern] = []

    static let limit = 32

    init(patterns: [SavedPattern] = []) {
        self.patterns = Array(patterns.prefix(Self.limit))
    }

    var isEmpty: Bool { patterns.isEmpty }
    var count: Int { patterns.count }
    var isFull: Bool { patterns.count >= Self.limit }

    subscript(id: UUID) -> SavedPattern? {
        patterns.first { $0.id == id }
    }

    /// The saved pattern drawn exactly like `bits`, if there is one.
    func pattern(matching bits: FatBits) -> SavedPattern? {
        patterns.first { $0.bits == bits }
    }

    /// Saves a drawing under a name. A drawing already saved is renamed
    /// rather than saved twice; a blank drawing is not saved. When the
    /// library is full the oldest pattern makes room. Returns the pattern
    /// as kept, or nil when nothing was saved.
    @discardableResult
    mutating func add(_ bits: FatBits, named name: String) -> SavedPattern? {
        guard !bits.isBlank else { return nil }
        if let index = patterns.firstIndex(where: { $0.bits == bits }) {
            patterns[index].name = SavedPattern.cleaned(name)
            return patterns[index]
        }
        let pattern = SavedPattern(name: name, bits: bits)
        patterns.append(pattern)
        if patterns.count > Self.limit { patterns.removeFirst(patterns.count - Self.limit) }
        return pattern
    }

    mutating func rename(id: UUID, to name: String) {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        patterns[index].name = SavedPattern.cleaned(name)
    }

    /// Changes a saved pattern's drawing, keeping its name and place.
    mutating func update(id: UUID, bits: FatBits) {
        guard let index = patterns.firstIndex(where: { $0.id == id }), !bits.isBlank else { return }
        patterns[index].bits = bits
    }

    mutating func remove(id: UUID) {
        patterns.removeAll { $0.id == id }
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        patterns.move(fromOffsets: source, toOffset: destination)
    }

    private enum CodingKeys: String, CodingKey { case patterns }

    /// A pattern that fails to decode is dropped, not fatal.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var list = try container.nestedUnkeyedContainer(forKey: .patterns)
        var decoded: [SavedPattern] = []
        while !list.isAtEnd {
            if let pattern = try? list.decode(SavedPattern.self) {
                decoded.append(pattern)
            } else {
                _ = try? list.decode(AnyCodableSkip.self)
            }
        }
        self.init(patterns: decoded)
    }
}

/// Decodes and discards any value, to step past an entry that cannot be read.
private struct AnyCodableSkip: Decodable {
    init(from decoder: Decoder) throws {}
}
