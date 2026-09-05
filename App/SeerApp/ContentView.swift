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
