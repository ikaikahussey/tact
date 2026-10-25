import SwiftUI

/// Links existing notes to a person.
struct LinkNotesView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID

    private var availableNotes: [Note] {
        store.sortedNotes.filter { !$0.isLinked(to: personID) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableNotes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes to Link", systemImage: "link.badge.plus")
                    } description: {
                        Text("Every note is already linked to this person.")
                    }
                } else {
                    List(availableNotes) { note in
                        Button {
                            store.linkNote(id: note.id, toPersonID: personID)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.text).foregroundStyle(.primary).lineLimit(2)
                                    HStack(spacing: 4) {
                                        Text(note.date, style: .date)
                                        let names = store.names(forPersonIDs: note.personIds)
                                        if !names.isEmpty {
                                            Text("· \(names.joined(separator: ", "))").lineLimit(1)
                                        }
                                    }
                                    .font(.tact(.caption)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").font(.tact(.title3))
                            }
                        }
                        .accessibilityHint("Links this note")
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Link Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
