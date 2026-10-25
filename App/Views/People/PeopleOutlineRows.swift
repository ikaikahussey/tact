import SwiftUI

/// A person in the People list. In outline mode a chevron shows or hides
/// their notes; the + starts a note, and the rest of the row opens the person.
struct PersonOutlineRow: View {
    /// How far notes sit in from the person's row, so they line up under the name.
    static let indent: CGFloat = 80

    let person: Person
    let noteCount: Int
    let showsChevron: Bool
    let isExpanded: Bool
    let toggle: () -> Void
    let addNote: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if showsChevron {
                chevron
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            NavigationLink {
                PersonDetailView(personID: person.id)
            } label: {
                PersonRow(person: person, noteCount: noteCount, addNote: addNote)
            }
        }
    }

    private var chevron: some View {
            Button(action: toggle) {
                Image(systemName: "chevron.right")
                    .font(.tact(.footnote).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 24, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide notes about \(person.name)" : "Show notes about \(person.name)")
    }
}

/// A note beneath a person in outline mode: its text, its date, and anyone
/// else it is about.
struct NoteOutlineRow: View {
    @EnvironmentObject private var store: TactStore
    let note: Note
    let personID: UUID

    private var others: String? {
        let names = store.names(forPersonIDs: note.personIds.filter { $0 != personID })
        return names.isEmpty ? nil : "With " + names.joined(separator: ", ")
    }

    var body: some View {
        NavigationLink {
            NoteDetailView(noteID: note.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.text)
                    .font(.tact(.subheadline))
                    .lineLimit(3)
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
            .padding(.leading, PersonOutlineRow.indent)
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
