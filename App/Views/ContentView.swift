import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PeopleTabView()
                .tabItem { Label("People", systemImage: "person.2.fill") }

            NotesListView()
                .tabItem { Label("Notes", systemImage: "note.text") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }
}
