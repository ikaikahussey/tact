import Foundation

/// The order people are offered in the note's person picker.
///
/// With no query: people most recently written about first, then everyone
/// else by name. With a query: names that start with it, then names with a
/// word that starts with it, then names that merely contain it; recency
/// breaks ties within each group.
enum PersonPickerOrder {
    static func people(_ people: [Person], notes: [Note], query rawQuery: String) -> [Person] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastWritten = lastNoteDates(notes)
        let ranked: [(person: Person, rank: Int)] = people.compactMap { person in
            guard let rank = matchRank(name: person.name, query: query) else { return nil }
            return (person, rank)
        }
        return ranked.sorted { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            let da = lastWritten[a.person.id], db = lastWritten[b.person.id]
            switch (da, db) {
            case let (x?, y?) where x != y: return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                return a.person.name.localizedStandardCompare(b.person.name) == .orderedAscending
            }
        }.map(\.person)
    }

    /// The query trimmed, when it names nobody yet and so can become a new
    /// person; `nil` when blank or when someone already has that exact name.
    static func newName(for rawQuery: String, among people: [Person]) -> String? {
        let name = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let taken = people.contains {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return taken ? nil : name
    }

    /// 0 = name starts with the query, 1 = a later word does, 2 = contains it,
    /// `nil` = no match. An empty query matches everyone at rank 0.
    static func matchRank(name: String, query: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        guard name.range(of: query, options: options) != nil else { return nil }
        if name.range(of: query, options: options.union(.anchored)) != nil { return 0 }
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
        if words.dropFirst().contains(where: { $0.range(of: query, options: options.union(.anchored)) != nil }) {
            return 1
        }
        return 2
    }

    private static func lastNoteDates(_ notes: [Note]) -> [UUID: Date] {
        var dates: [UUID: Date] = [:]
        for note in notes {
            for id in note.personIds where (dates[id] ?? .distantPast) < note.date {
                dates[id] = note.date
            }
        }
        return dates
    }
}
