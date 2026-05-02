import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var diagnosticsConsent = DiagnosticsConsent.shared
    @State private var showPiPRestorePlayer = false
    @State private var showDiagnosticsConsent = false

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(onboardingManager)
            } else {
                OnboardingFlowView(appState: appState, onboardingManager: onboardingManager)
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
                appName: "Flowmark",
                features: WhatsNewData.features,
                onContinue: {
                    onboardingManager.markWhatsNewSeen()
                    // Show diagnostics consent after What's New if needed
                    if diagnosticsConsent.needsConsentPrompt {
                        showDiagnosticsConsent = true
                    }
                }
            )
            .interactiveDismissDisabled()
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showDiagnosticsConsent) {
            DiagnosticsConsentSheet()
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
                // If no What's New to show, check if we need consent prompt
                if !onboardingManager.showWhatsNew, diagnosticsConsent.needsConsentPrompt {
                    showDiagnosticsConsent = true
                }
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
