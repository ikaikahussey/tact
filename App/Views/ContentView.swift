import SwiftUI

struct ContentView: View {
    @AppStorage(RootTab.storageKey) private var selectedTab: RootTab = .people
    @AppStorage(AppPalette.storageKey) private var palette: AppPalette = .classic

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                PeopleRootView(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .font(.tact(.body))
        .tint(palette.accent)
        .environment(\.appPalette, palette)
    }
}
