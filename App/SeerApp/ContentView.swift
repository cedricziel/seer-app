import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var wifiMonitor = WiFiSSIDMonitor.shared
    @State private var resolvedContext: ServerURLResolver.Context?
    @State private var showPiPRestorePlayer = false

    private var resolutionContext: ServerURLResolver.Context? {
        _ = wifiMonitor.networkRevision
        _ = wifiMonitor.currentSSID
        guard let server = appState.activeServer else { return nil }
        return ServerURLResolver.shared.context(for: server)
    }

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if resolvedContext == resolutionContext {
                    MainTabView()
                        .environmentObject(onboardingManager)
                } else {
                    ProgressView("Connecting to server...")
                }
            } else {
                OnboardingFlowView(appState: appState, onboardingManager: onboardingManager)
                    .environmentObject(onboardingManager)
            }
        }
        .task(id: resolutionContext) {
            guard let server = appState.activeServer else { return }
            let context = resolutionContext
            _ = await ServerURLResolver.shared.probeAndResolve(for: server)
            guard !Task.isCancelled, context == resolutionContext else { return }
            resolvedContext = context
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                wifiMonitor.refresh()
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
                appName: "Flowmark",
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
    @State private var selectedTab: MainTab = .library

    /// Named `MainTab` (not `Tab`) to avoid colliding with SwiftUI's `Tab` view type used below.
    enum MainTab: Hashable {
        case library
        case discover
        case search
        case downloads
        case requests
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "play.square.stack", value: .library) {
                LibraryView()
            }

            Tab("Discover", systemImage: "sparkles", value: .discover) {
                DiscoverView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }

            Tab("Downloads", systemImage: "arrow.down.circle", value: .downloads) {
                DownloadsView()
            }

            Tab("Requests", systemImage: "list.bullet.clipboard", value: .requests) {
                RequestsView()
            }
        }
        #if os(iOS)
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
