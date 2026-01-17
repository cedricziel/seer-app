import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showPiPRestorePlayer = false

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(onboardingManager)
            } else {
                ServerSetupView()
                    .environmentObject(onboardingManager)
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .fullScreenCover(isPresented: $showPiPRestorePlayer) {
            let pipManager = PiPPlaybackManager.shared
            if let item = pipManager.pipItem,
               let player = pipManager.pipPlayer {
                VideoPlayerView(
                    item: item,
                    appState: appState,
                    startPositionTicks: 0,
                    existingPlayer: player,
                    onPiPStart: { showPiPRestorePlayer = false }
                )
            } else {
                Color.clear.onAppear { showPiPRestorePlayer = false }
            }
        }
        .sheet(isPresented: $onboardingManager.showWhatsNew) {
            WhatsNewView(
                appName: "Seer",
                features: WhatsNewData.features,
                onContinue: {
                    onboardingManager.markWhatsNewSeen()
                }
            )
            .interactiveDismissDisabled()
            .presentationDetents([.large])
        }
        .onChange(of: PiPPlaybackManager.shared.shouldRestorePlayer) { _, shouldRestore in
            if shouldRestore {
                showPiPRestorePlayer = true
                PiPPlaybackManager.shared.clearRestoreRequest()
            }
        }
        .onAppear {
            if appState.isAuthenticated {
                onboardingManager.checkAndShowWhatsNew()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .library

    enum Tab: Hashable {
        case library
        case discover
        case search
        case downloads
        case requests
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "play.square.stack")
                }
                .tag(Tab.library)

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(Tab.discover)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .tag(Tab.downloads)

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
