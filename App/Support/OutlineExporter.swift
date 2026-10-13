import Foundation

/// Builds the plain-text outline that "Export Outline" shares.
enum OutlineExporter {
    static let previewLength = 100

    static func outline(people: [Person], notes: [Note], now: Date = Date()) -> String {
        var outline = "TACT OUTLINE\n"
        outline += "Generated: \(now.formatted(date: .long, time: .shortened))\n\n"
        outline += String(repeating: "=", count: 51) + "\n\n"

        if people.isEmpty {
            outline += "No people added yet.\n\n"
        } else {
            outline += "PEOPLE (\(people.count))\n\n"
            for person in people {
                outline += "• \(person.name)\n"
                let personNotes = notes.filter { $0.isLinked(to: person.id) }.sorted { $0.date > $1.date }
                if !personNotes.isEmpty {
                    outline += "  Notes (\(personNotes.count)):\n"
                    for note in personNotes {
                        outline += "    - \(line(for: note))\n"
                    }
                }
                outline += "\n"
            }
        }

        let unlinked = notes.filter { $0.personIds.isEmpty }.sorted { $0.date > $1.date }
        if !unlinked.isEmpty {
            outline += "UNLINKED NOTES (\(unlinked.count))\n\n"
            for note in unlinked {
                outline += "  - \(line(for: note))\n"
            }
        }
        return outline
    }

    private static func line(for note: Note) -> String {
        let date = note.date.formatted(date: .abbreviated, time: .omitted)
        let singleLine = note.text.replacingOccurrences(of: "\n", with: " ")
        let preview = singleLine.prefix(previewLength)
        let ellipsis = singleLine.count > previewLength ? "..." : ""
        return "[\(date)] \(preview)\(ellipsis)"
    }
}
