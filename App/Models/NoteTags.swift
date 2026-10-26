import Foundation

/// Tags are hashtags typed inside a note: `#birthday`, `#work`. They are
/// read out of the text, never stored on their own, so nothing migrates
/// and a note's tags are always what its text says.
enum NoteTags {
    /// A `#` followed by letters, digits, hyphens or underscores. The `#`
    /// must start the text or follow whitespace or punctuation, so `C#` and
    /// `a#b` are not tags.
    private static let pattern = try! NSRegularExpression(pattern: #"(?<![\p{L}\p{N}_])#([\p{L}\p{N}_-]+)"#)

    /// The tags in `text`, as typed, in order, each once (case-insensitively).
    static func tags(in text: String) -> [String] {
        var seen = Set<String>()
        var tags: [String] = []
        let range = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: range) {
            guard let tagRange = Range(match.range(at: 1), in: text) else { continue }
            let tag = String(text[tagRange])
            if seen.insert(normalized(tag)).inserted { tags.append(tag) }
        }
        return tags
    }

    /// The form tags are compared in.
    static func normalized(_ tag: String) -> String {
        tag.lowercased()
    }

    /// Whether `query` (with or without its `#`) names a tag search.
    static func isTagQuery(_ query: String) -> Bool {
        query.hasPrefix("#")
    }

    /// The tag named by a `#` query, normalized; nil when it is not one or
    /// nothing follows the `#`.
    static func queryTag(_ query: String) -> String? {
        guard isTagQuery(query) else { return nil }
        let tag = query.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? nil : normalized(tag)
    }

    /// The word being typed at the end of `text` if it is the start of a
    /// tag: the characters after its `#`, which may be empty.
    static func partialTag(endOf text: String) -> String? {
        guard let hashIndex = text.lastIndex(of: "#") else { return nil }
        let before = text[..<hashIndex]
        if let last = before.last, last.isLetter || last.isNumber || last == "_" { return nil }
        let after = text[text.index(after: hashIndex)...]
        guard after.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else { return nil }
        return String(after)
    }

    /// `text` with the tag being typed at its end completed to `tag`,
    /// followed by a space.
    static func completing(_ text: String, with tag: String) -> String {
        guard let hashIndex = text.lastIndex(of: "#") else { return text }
        return String(text[..<hashIndex]) + "#" + tag + " "
    }
}

extension Note {
    /// The tags typed in this note, as typed, in order.
    var tags: [String] { NoteTags.tags(in: text) }

    func hasTag(_ normalized: String) -> Bool {
        tags.contains { NoteTags.normalized($0) == normalized }
    }
}

/// A tag and how often it is used, for the suggestion strips.
struct TagCount: Identifiable, Equatable {
    let tag: String
    let count: Int
    var id: String { NoteTags.normalized(tag) }

    /// Every tag across `notes`, most used first, then alphabetical. Each
    /// is shown as it was first typed.
    static func counts(in notes: [Note]) -> [TagCount] {
        var counts: [String: (tag: String, count: Int)] = [:]
        for note in notes {
            for tag in note.tags {
                let key = NoteTags.normalized(tag)
                counts[key] = (counts[key]?.tag ?? tag, (counts[key]?.count ?? 0) + 1)
            }
        }
        return counts.values
            .map { TagCount(tag: $0.tag, count: $0.count) }
            .sorted { ($1.count, $0.id) < ($0.count, $1.id) }
    }

    /// The tags that start with `prefix` (normalized), or all when it is empty.
    static func matching(_ prefix: String, in counts: [TagCount]) -> [TagCount] {
        let prefix = NoteTags.normalized(prefix)
        return prefix.isEmpty ? counts : counts.filter { $0.id.hasPrefix(prefix) }
    }
}
