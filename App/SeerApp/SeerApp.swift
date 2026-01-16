import Kingfisher
import OfflineSync
import SeerCore
import SwiftData
import SwiftUI

@main
struct SeerApp: App {
    @StateObject private var appState: AppState
    @StateObject private var offlineSyncService: OfflineSyncService
    @StateObject private var networkMonitor: NetworkMonitor

    let modelContainer: ModelContainer

    init() {
        // Configure Kingfisher cache limits
        Self.configureImageCache()

        // Configure SwiftData with CloudKit
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
