import SwiftUI

struct ContentView: View {
    enum Tab: String { case people, notes, search }

    @AppStorage("selectedTab") private var selectedTab: Tab = .people

    var body: some View {
        TabView(selection: $selectedTab) {
            PeopleTabView()
                .tabItem { Label("People", systemImage: "person.2.fill") }
                .tag(Tab.people)

            NotesListView()
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(Tab.notes)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
        }
    }
}
