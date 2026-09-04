import DownloadClient
import Kingfisher
import NotificationClient
import OfflineSync
import SeerCore
import SwiftData
import SwiftUI

@main
struct SeerApp: App {
    @UIApplicationDelegateAdaptor(SeerAppDelegate.self) private var appDelegate
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
    @State private var spotlightIndexer: SpotlightIndexer?

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
                .environmentObject(appState)
                .environmentObject(offlineSyncService)
                .environmentObject(networkMonitor)
                .environmentObject(flowmarkRouter)
                .modelContainer(modelContainer)
                .task {
                    await setupServices()
                }
                .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        configureServicesCredentials()
                    }
                }
                .onChange(of: appState.activeServerID) { _, _ in
                    configureServicesCredentials()
                }
                .onChange(of: appState.appIntentsIndexingEnabled) { _, _ in
                    spotlightIndexer?.reconcile()
                }
                .onOpenURL { url in
                    flowmarkRouter.route(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    // BGTaskScheduler only runs tasks that have been submitted;
                    // registering the handlers alone never schedules a first run.
                    if phase == .background {
                        appDelegate.scheduleRequestPollTask()
                        appDelegate.scheduleAutoDownloadTask()
                    }
                }
                .environment(downloadManager)
                .environment(notificationManager)
        }
    }

    @MainActor
    private func configureServicesCredentials() {
        // Configure download manager
        downloadManager?.configure(from: appState)

        // (Re)bind the request status poller to the active server
        if let service = requestNotificationService {
            ensureRequestStatusPoller(notificationService: service)
        }
    }

    /// Creates a poller for the active server if none exists yet or the active
    /// server changed, then configures it with the server's Jellyseerr
    /// credentials. A poller is bound to one server ID for the lifetime of
    /// its cache, so switching servers must replace it rather than reconfigure it.
    @MainActor
    private func ensureRequestStatusPoller(notificationService: RequestNotificationService) {
        guard let serverKey = appState.activeServerKey else { return }

        let poller: RequestStatusPoller
        if let existing = requestStatusPoller, existing.serverID == serverKey {
            poller = existing
        } else {
            let previous = requestStatusPoller
            Task { await previous?.stopPolling() }
            poller = RequestStatusPoller(
                modelContainer: notificationModelContainer,
                notificationService: notificationService,
                serverID: serverKey
            )
            requestStatusPoller = poller
            appDelegate.requestStatusPoller = poller
        }

        guard let jellyseerrURL = appState.jellyseerrServerURL,
              let apiKey = appState.jellyseerrAPIKey
        else { return }
        Task {
            await poller.configure(serverURL: jellyseerrURL, apiKey: apiKey)
            await poller.startPolling()
        }
    }

    @MainActor
    private func setupServices() async {
        // Wire up Spotlight indexing — gated behind the per-device
        // privacy flag (`appIntentsIndexingEnabled`, default off).
        let indexer = SpotlightIndexer(
            appState: appState,
            modelContainer: modelContainer
        )
        spotlightIndexer = indexer
        indexer.reconcile()

        // Notification manager was created in `init`; wire the rest here
        guard let notifManager = notificationManager else { return }
        appDelegate.notificationManager = notifManager

        // Setup request notification service
        let reqNotifService = RequestNotificationService(notificationManager: notifManager)
        requestNotificationService = reqNotifService

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
        ensureRequestStatusPoller(notificationService: reqNotifService)
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
