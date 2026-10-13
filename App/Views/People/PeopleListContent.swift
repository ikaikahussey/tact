import SwiftUI

struct PeopleListContent: View {
    @EnvironmentObject private var store: TactStore

    var body: some View {
        List {
            ForEach(store.people) { person in
                NavigationLink {
                    PersonDetailView(personID: person.id)
                } label: {
                    PersonRow(person: person, noteCount: store.noteCount(for: person.id))
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { store.people[$0].id }
                ids.forEach { store.deletePerson(id: $0) }
            }
            .onMove { source, destination in
                store.movePeople(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "person.2")
                } description: {
                    Text("Tap + to add someone, then keep notes about them.")
                }
            }
        }
        .toolbar {
            if !store.people.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}

struct PersonRow: View {
    let person: Person
    let noteCount: Int

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                if let contactName = person.contact?.name, contactName != person.name {
                    Text(contactName).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tactTileGray)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(noteCount) notes")
            }
        }
    }
}
