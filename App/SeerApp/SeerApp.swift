import DownloadClient
import Kingfisher
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
    @State private var downloadManager: DownloadManager?

    let modelContainer: ModelContainer
    let downloadModelContainer: ModelContainer

    init() {
        // Configure Kingfisher cache limits
        Self.configureImageCache()

        // Configure SwiftData with CloudKit for app data
        let schema = Schema([
            ServerConfiguration.self,
            CachedLibrary.self,
            CachedMediaItem.self,
            CachedUserProgress.self
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

        // Initialize AppState
        let state = AppState()
        _appState = StateObject(wrappedValue: state)

        // Set the model context on AppState
        state.setModelContext(modelContainer.mainContext)

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
                .modelContainer(modelContainer)
                .task {
                    await setupDownloadManager()
                }
                .environment(downloadManager)
        }
    }

    @MainActor
    private func setupDownloadManager() async {
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

            downloadManager = manager
            appDelegate.downloadManager = manager
        } catch {
            print("Failed to initialize DownloadManager: \(error)")
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
