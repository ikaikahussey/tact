import SwiftUI

/// Filters people and notes as the user types.
struct SearchView: View {
    @EnvironmentObject private var store: TactStore
    @State private var searchText = ""

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    private var filteredPeople: [Person] {
        guard !query.isEmpty else { return [] }
        return store.people.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.contact?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var filteredNotes: [Note] {
        guard !query.isEmpty else { return [] }
        return store.sortedNotes.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabHeader("Search")
                results
            }
            .background(Color.tactBackground)
            .navigationTitle("Search")
            .appTitleBar()
            .searchable(text: $searchText, prompt: "Search people and notes")
        }
    }

    private var results: some View {
            Group {
                if query.isEmpty {
                    ContentUnavailableView {
                        Label("Search Tact", systemImage: "magnifyingglass")
                    } description: {
                        Text("Find people by name and notes by their text.")
                    }
                } else if filteredPeople.isEmpty && filteredNotes.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        if !filteredPeople.isEmpty {
                            Section("People") {
                                ForEach(filteredPeople) { person in
                                    NavigationLink {
                                        PersonDetailView(personID: person.id)
                                    } label: {
                                        PersonRow(person: person, noteCount: store.noteCount(for: person.id))
                                    }
                                }
                            }
                        }
                        if !filteredNotes.isEmpty {
                            Section("Notes") {
                                ForEach(filteredNotes) { note in
                                    NavigationLink {
                                        NoteDetailView(noteID: note.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            let names = store.names(forPersonIDs: note.personIds)
                                            if !names.isEmpty {
                                                Text(names.joined(separator: ", ")).font(.tact(.caption)).foregroundStyle(.secondary)
                                            }
                                            Text(note.text).lineLimit(3)
                                            Text(note.date, style: .date).font(.tact(.caption)).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
    }
}
