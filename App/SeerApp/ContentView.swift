import SeerCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                ServerSetupView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .library

    enum Tab: Hashable {
        case library
        case search
        case requests
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "play.square.stack")
                }
                .tag(Tab.library)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            RequestsView()
                .tabItem {
                    Label("Requests", systemImage: "list.bullet.clipboard")
                }
                .tag(Tab.requests)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
