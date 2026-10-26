#if os(iOS)
    import BackgroundTasks
#endif
import DownloadClient
import JellyfinClient
import Kingfisher
import NotificationClient
import OfflineSync
import SeerCore
import SwiftData
import SwiftUI

struct SeerApp: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(SeerAppDelegate.self) private var appDelegate
    #else
        @UIApplicationDelegateAdaptor(SeerAppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appState: AppState
    @StateObject private var offlineSyncService: OfflineSyncService
    @StateObject private var networkMonitor: NetworkMonitor
    @StateObject private var flowmarkRouter = FlowmarkURLRouter()
    @State private var downloadManager: DownloadManager?
    @State private var notificationManager: NotificationManager?
    @State private var downloadNotificationService: DownloadNotificationService?
    @State private var requestNotificationService: RequestNotificationService?
    @State private var requestStatusPoller: RequestStatusPoller?
    @State private var requestPollingTask: Task<Void, Never>?
    #if !os(tvOS)
        @State private var spotlightIndexer: SpotlightIndexer?
    #endif

    let modelContainer: ModelContainer
    let downloadModelContainer: ModelContainer
    let notificationModelContainer: ModelContainer

    init() {
        // Configure Kingfisher cache limits
        Self.configureImageCache()

        // Configure SwiftData with CloudKit for app data
        let schema = Schema([
            ServerConfiguration.self,
            CachedLibrary.self,
            CachedMediaItem.self,
            CachedUserProgress.self,
            CachedRequest.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.cedricziel.seer")
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Create separate model container for downloads (no CloudKit - per-device)
        do {
            downloadModelContainer = try createDownloadModelContainer()
        } catch {
            fatalError("Failed to create download ModelContainer: \(error)")
        }

        // Create separate model container for notifications (no CloudKit - per-device)
        do {
            notificationModelContainer = try createNotificationModelContainer()
        } catch {
            fatalError("Failed to create notification ModelContainer: \(error)")
        }

        // Initialize AppState
        let state = AppState()
        _appState = StateObject(wrappedValue: state)

        // Set the model context on AppState
        state.setModelContext(modelContainer.mainContext)

        // Register the SwiftData container with App Intents queries so
        // entity queries (MediaItemEntityQuery, RequestEntityQuery,
        // ServerEntityQuery) can read from the same store the app uses.
        AppIntentsContext.modelContainer = modelContainer
        AppIntentsContext.appState = state

        // Initialize OfflineSyncService
        let syncService = OfflineSyncService(modelContext: modelContainer.mainContext)
        _offlineSyncService = StateObject(wrappedValue: syncService)

        // Initialize NetworkMonitor
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor.shared)

        // The notification center delegate must be in place before
        // `application(_:didFinishLaunchingWithOptions:)` returns, otherwise a
        // notification tap that cold-launches the app is never delivered.
        let notifManager = NotificationManager(modelContainer: notificationModelContainer)
        appDelegate.requestPollingAllowed = { [weak state] in
            guard let state else { return false }
            return state.isAuthenticated && state.activeServerKey != nil
                && state.jellyseerrServerURL != nil && state.jellyseerrAPIKey != nil
        }
        notifManager.actionDelegate = appDelegate
        notifManager.setup()
        _notificationManager = State(initialValue: notifManager)

        // Create the download manager synchronously at launch so it owns the
        // background URLSession delegate before iOS delivers any
        // `handleEventsForBackgroundURLSession` callbacks. A SwiftUI `.task`
        // never runs for a UI-less background relaunch, which previously meant
        // completed downloads were dropped.
        do {
            let manager = try DownloadManager(modelContainer: downloadModelContainer)
            manager.configure(from: state)
            _downloadManager = State(initialValue: manager)
        } catch {
            print("Failed to initialize DownloadManager: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
            #endif
                .environmentObject(appState)
                .environmentObject(offlineSyncService)
                .environmentObject(networkMonitor)
                .environmentObject(flowmarkRouter)
                .environmentObject(appDelegate.notificationNavigation)
                .modelContainer(modelContainer)
                .task {
                    await setupServices()
                }
                .onChange(of: appState.isAuthenticated) { _, _ in
                    configureServicesCredentials()
                }
                .onChange(of: appState.activeServerID) { _, _ in
                    configureServicesCredentials()
                }
                .onChange(of: appState.jellyfinServerURL) { _, _ in
                    downloadManager?.configure(from: appState)
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    if isConnected {
                        syncDownloadedPlaybackProgress()
                    }
                }
            #if !os(tvOS)
                .onChange(of: appState.appIntentsIndexingEnabled) { _, _ in
                    spotlightIndexer?.reconcile()
                }
            #endif
                .onOpenURL { url in
                    flowmarkRouter.route(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        syncDownloadedPlaybackProgress()
                    }
                    // BGTaskScheduler only runs tasks that have been submitted;
                    // registering the handlers alone never schedules a first run.
                    #if os(iOS)
                        if phase == .background {
                            appDelegate.scheduleRequestPollTask()
                            appDelegate.scheduleAutoDownloadTask()
                        }
                    #endif
                }
                .environment(downloadManager)
                .environment(notificationManager)
        }
    }

    @MainActor
    private func configureServicesCredentials() {
        // Configure download manager
        downloadManager?.configure(from: appState)
        syncDownloadedPlaybackProgress()

        configureRequestPolling()
    }

    @MainActor
    private func syncDownloadedPlaybackProgress() {
        guard networkMonitor.isConnected,
              let manager = downloadManager,
              let serverID = appState.activeServerKey,
              let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID,
              let deviceID = appState.jellyfinDeviceID
        else { return }

        let service = JellyfinService(
            serverURL: serverURL, accessToken: accessToken, userID: userID, deviceID: deviceID
        )
        Task {
            await manager.syncPlaybackProgress(serverID: serverID) { progress in
                try await service.reportPlaybackProgress(
                    itemId: progress.itemID, positionTicks: progress.positionTicks, isPaused: true
                )
                if progress.isWatched {
                    try await service.markAsPlayed(itemId: progress.itemID)
                }
            }
        }
    }

    @MainActor
    private func configureRequestPolling() {
        requestPollingTask?.cancel()
        requestPollingTask = nil
        requestNotificationService?.retire()
        requestNotificationService = nil
        let previous = requestStatusPoller
        requestStatusPoller = nil
        appDelegate.requestStatusPoller = nil
        #if os(iOS)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SeerAppDelegate.requestPollTaskIdentifier)
        #endif
        Task { await previous?.retire() }

        guard appState.isAuthenticated, let serverKey = appState.activeServerKey,
              let url = appState.jellyseerrServerURL, let apiKey = appState.jellyseerrAPIKey,
              let notificationManager
        else { return }
        let state = appState
        let service = RequestNotificationService(notificationManager: notificationManager) {
            state.isAuthenticated && state.activeServerKey == serverKey
        }
        let poller = RequestStatusPoller(
            modelContainer: notificationModelContainer,
            notificationService: service,
            serverID: serverKey
        )
        requestNotificationService = service
        requestStatusPoller = poller
        appDelegate.requestStatusPoller = poller
        requestPollingTask = Task {
            guard !Task.isCancelled else { return }
            await poller.configure(serverURL: url, apiKey: apiKey)
            guard !Task.isCancelled else { return }
            await poller.startPolling()
        }
    }

    @MainActor
    private func setupServices() async {
        syncDownloadedPlaybackProgress()
        #if !os(tvOS)
            let indexer = SpotlightIndexer(
                appState: appState,
                modelContainer: modelContainer
            )
            spotlightIndexer = indexer
            indexer.reconcile()
        #endif

        // Notification manager was created in `init`; wire the rest here
        guard let notifManager = notificationManager else { return }
        appDelegate.notificationManager = notifManager

        // Setup download notification service
        let dlNotifService = DownloadNotificationService(notificationManager: notifManager)
        downloadNotificationService = dlNotifService

        // Set app delegate as action delegate
        notifManager.actionDelegate = appDelegate

        // Wire up the download manager created in `init`
        if let manager = downloadManager {
            manager.notificationDelegate = dlNotifService
            appDelegate.downloadManager = manager
        }

        // Install production implementations for the App Intent test
        // seams (RequestMediaIntent.submitter, SearchMediaIntent.
        // discoverSupplement, MarkAsWatchedIntent.updater,
        // DownloadForOfflineIntent.enqueuer). Replaces the defaults
        // that throw `serverNotReachable`.
        IntentSeams.install(
            appState: appState,
            downloadManager: downloadManager
        )

        // Setup request status poller for the active server (if any)
        configureRequestPolling()
    }

    /// Configures Kingfisher image cache with appropriate limits
    private static func configureImageCache() {
        let cache = ImageCache.default

        // Memory cache: 100 MB
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024

        // Disk cache: 500 MB
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024

        // Cache expiration: 30 days
        cache.diskStorage.config.expiration = .days(30)
    }
}
