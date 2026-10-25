import NotificationClient
import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notificationNavigation: NotificationNavigation
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var wifiMonitor = WiFiSSIDMonitor.shared
    @State private var resolvedContext: ServerURLResolver.Context?
    @State private var resolvedServerURL: URL?
    @State private var showPiPRestorePlayer = false

    private var resolutionContext: ServerURLResolver.Context? {
        guard let server = appState.activeServer else { return nil }
        return ServerURLResolver.shared.context(for: server)
    }

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if let resolvedContext, let currentContext = resolutionContext,
                   resolvedContext.matchesConfiguration(of: currentContext) {
                    MainTabView()
                        .id(resolvedServerURL)
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
            guard let serverURL = await appState.resolveJellyfinURL(for: server.id) else { return }
            guard !Task.isCancelled, context == resolutionContext else { return }
            resolvedServerURL = serverURL
            resolvedContext = context
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                wifiMonitor.refresh()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .onChange(of: notificationNavigation.pendingDestination?.id, initial: true) { _, _ in
            guard let destination = notificationNavigation.pendingDestination,
                  appState.servers.contains(where: { $0.id == destination.serverID }),
                  appState.activeServerID != destination.serverID
            else { return }
            appState.switchServer(to: destination.serverID)
        }
        .playerCover(isPresented: $showPiPRestorePlayer) {
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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var flowmarkRouter: FlowmarkURLRouter
    @EnvironmentObject private var notificationNavigation: NotificationNavigation
    @State private var showNotificationError = false
    @State private var notificationDestination: NotificationNavigation.Destination?

    var body: some View {
        TabView(selection: $flowmarkRouter.selectedTab) {
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
        .task(id: notificationNavigation.pendingDestination?.id) {
            openNotificationDestination()
        }
        .sheet(item: $notificationDestination) { destination in
            NotificationDestinationView(destination: destination)
                .id(destination.id)
        }
        .alert("Notification unavailable", isPresented: $showNotificationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The notification's server is no longer configured.")
        }
        #if os(iOS)
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }

    private func openNotificationDestination() {
        guard let pending = notificationNavigation.pendingDestination else { return }
        guard appState.servers.contains(where: { $0.id == pending.serverID }) else {
            notificationNavigation.clear()
            showNotificationError = true
            return
        }
        guard let destination = notificationNavigation.consume(activateServer: { serverID in
            if appState.activeServerID != serverID {
                appState.switchServer(to: serverID)
            }
            return appState.activeServerID == serverID && appState.isAuthenticated
        }) else { return }
        switch destination {
        case .request: flowmarkRouter.selectedTab = .requests
        case .download: flowmarkRouter.selectedTab = .downloads
        }
        notificationDestination = destination
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(FlowmarkURLRouter())
        .environmentObject(NotificationNavigation())
}
