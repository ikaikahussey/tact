import SwiftUI

/// A note in the list: its text, its date, and who it is about. Beneath a
/// person (`personID`) that is anyone else; in the Recent grouping, with
/// no person heading the section, it is everyone.
struct NoteOutlineRow: View {
    @EnvironmentObject private var store: TactStore
    let note: Note
    var personID: UUID? = nil

    private var others: String? {
        let names = store.names(forPersonIDs: note.personIds.filter { $0 != personID })
        guard !names.isEmpty else { return nil }
        return (personID == nil ? "" : "With ") + names.joined(separator: ", ")
    }

    var body: some View {
        NavigationLink(value: Route.note(note.id)) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.text)
                    .font(.tact(.subheadline))
                    .lineLimit(3)
                if !note.tags.isEmpty {
                    TagChips(tags: note.tags)
                }
                HStack(spacing: 6) {
                    Text(note.date, style: .date)
                    if let others {
                        Text("·")
                        Text(others).lineLimit(1)
                    }
                }
                .font(.tact(.caption))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            ShareLink(item: note.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { store.deleteNote(id: note.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
