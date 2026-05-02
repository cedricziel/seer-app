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
                .environment(downloadManager)
                .environment(notificationManager)
        }
    }

    @MainActor
    private func configureServicesCredentials() {
        // Configure download manager
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else { return }

        manager.configure(
            serverURL: credentials.serverURL,
            accessToken: credentials.accessToken,
            userID: credentials.userId,
            deviceID: credentials.deviceId
        )

        // Configure request status poller with Jellyseerr credentials
        if let jellyseerrURL = appState.jellyseerrServerURL,
           let apiKey = appState.jellyseerrAPIKey,
           let poller = requestStatusPoller {
            Task {
                await poller.configure(serverURL: jellyseerrURL, apiKey: apiKey)
                await poller.startPolling()
            }
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

        // Setup notification manager first
        let notifManager = NotificationManager(modelContainer: notificationModelContainer)
        notifManager.setup()
        notificationManager = notifManager
        appDelegate.notificationManager = notifManager

        // Setup request notification service
        let reqNotifService = RequestNotificationService(notificationManager: notifManager)
        requestNotificationService = reqNotifService

        // Setup download notification service
        let dlNotifService = DownloadNotificationService(notificationManager: notifManager)
        downloadNotificationService = dlNotifService

        // Set app delegate as action delegate
        notifManager.actionDelegate = appDelegate

        // Setup download manager
        do {
            let manager = try DownloadManager(modelContainer: downloadModelContainer)

            // Configure with credentials when available
            if let credentials = appState.jellyfinCredentials {
                manager.configure(
                    serverURL: credentials.serverURL,
                    accessToken: credentials.accessToken,
                    userID: credentials.userId,
                    deviceID: credentials.deviceId
                )
            }

            // Set notification delegate
            manager.notificationDelegate = dlNotifService

            downloadManager = manager
            appDelegate.downloadManager = manager
        } catch {
            print("Failed to initialize DownloadManager: \(error)")
        }

        // Setup request status poller
        if let serverID = appState.activeServerID {
            let poller = RequestStatusPoller(
                modelContainer: notificationModelContainer,
                notificationService: reqNotifService,
                serverID: serverID.uuidString
            )
            requestStatusPoller = poller
            appDelegate.requestStatusPoller = poller

            // Configure and start polling if Jellyseerr is configured
            if let jellyseerrURL = appState.jellyseerrServerURL,
               let apiKey = appState.jellyseerrAPIKey {
                await poller.configure(serverURL: jellyseerrURL, apiKey: apiKey)
                await poller.startPolling()
            }
        }
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
