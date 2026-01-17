import Foundation
import JellyfinClient
import SeerCore
import SwiftData

/// Main orchestrator for offline sync operations
@MainActor
public final class OfflineSyncService: ObservableObject {
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingChangesCount: Int = 0

    private let modelContext: ModelContext
    private let librarySyncService: LibrarySyncService
    private let mediaItemSyncService: MediaItemSyncService
    private let userProgressSyncService: UserProgressSyncService
    private let imagePrefetchService: ImagePrefetchService

    /// Minimum time between automatic syncs (1 hour)
    private let minSyncInterval: TimeInterval = 3600

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        librarySyncService = LibrarySyncService(modelContext: modelContext)
        mediaItemSyncService = MediaItemSyncService(modelContext: modelContext)
        userProgressSyncService = UserProgressSyncService(modelContext: modelContext)
        imagePrefetchService = ImagePrefetchService()
    }

    // MARK: - Public Methods

    /// Performs a full sync for the given server configuration
    public func syncServer(
        _ serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Sync libraries first
        try await librarySyncService.syncLibraries(
            serverConfig: serverConfig,
            service: service
        )

        // Load cached libraries to sync items
        let configID = serverConfig.id
        let descriptor = FetchDescriptor<CachedLibrary>(
            predicate: #Predicate { $0.serverConfigurationID == configID }
        )
        let libraries = try modelContext.fetch(descriptor)

        // Sync items for each library (up to limit)
        for library in libraries {
            try await mediaItemSyncService.syncLibraryItems(
                library: library,
                serverConfig: serverConfig,
                service: service
            )
        }

        // Prefetch images for cached items
        try await imagePrefetchService.prefetchImages(
            for: serverConfig,
            modelContext: modelContext,
            service: service
        )

        lastSyncDate = Date()
        updatePendingChangesCount()
    }

    /// Performs an incremental sync (continue watching, latest items)
    public func incrementalSync(
        _ serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        guard !isSyncing else { return }

        // Check if enough time has passed since last sync
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Sync continue watching and latest items
        try await mediaItemSyncService.syncContinueWatching(
            serverConfig: serverConfig,
            service: service
        )

        try await mediaItemSyncService.syncLatestItems(
            serverConfig: serverConfig,
            service: service
        )

        lastSyncDate = Date()
        updatePendingChangesCount()
    }

    /// Flushes all pending progress changes to the server
    public func flushPendingProgress(
        _ serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async {
        await userProgressSyncService.flushPendingProgress(
            serverConfig: serverConfig,
            service: service
        )
        updatePendingChangesCount()
    }

    /// Saves progress locally and queues for sync
    public func saveProgress(
        mediaItemId: String,
        serverConfigurationID: UUID,
        playbackPositionTicks: Int64,
        isFavorite: Bool,
        isPlayed: Bool
    ) {
        userProgressSyncService.queueProgressUpdate(
            mediaItemId: mediaItemId,
            serverConfigurationID: serverConfigurationID,
            playbackPositionTicks: playbackPositionTicks,
            isFavorite: isFavorite,
            isPlayed: isPlayed
        )
        updatePendingChangesCount()

        // Also update the cached media item
        mediaItemSyncService.updateCachedItemProgress(
            mediaItemId: mediaItemId,
            playbackPositionTicks: playbackPositionTicks,
            isFavorite: isFavorite,
            isPlayed: isPlayed
        )
    }

    /// Cleans up old cached data
    public func cleanupOldCache(olderThan days: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        try mediaItemSyncService.removeOldItems(olderThan: cutoffDate)
    }

    /// Removes all cached data for a server
    public func removeServerCache(serverConfigurationID: UUID) throws {
        try librarySyncService.removeLibraries(for: serverConfigurationID)
        try mediaItemSyncService.removeItems(for: serverConfigurationID)
        userProgressSyncService.removePendingProgress(for: serverConfigurationID)
    }

    /// Checks if a sync is needed (more than minSyncInterval since last sync)
    public var needsSync: Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) >= minSyncInterval
    }

    // MARK: - Private Methods

    private func updatePendingChangesCount() {
        pendingChangesCount = userProgressSyncService.getPendingChangesCount()
    }
}
