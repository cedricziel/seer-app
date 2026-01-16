import Foundation
import JellyfinClient
import SeerCore
import SwiftData

/// Handles syncing of user progress (playback position, favorites, played status)
@MainActor
public final class UserProgressSyncService {
    private let modelContext: ModelContext
    private let conflictResolver = ConflictResolver()

    /// Maximum retry attempts before giving up
    private let maxRetryAttempts = 3

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Queue Management

    /// Queues a progress update for sync
    public func queueProgressUpdate(
        mediaItemId: String,
        serverConfigurationID: UUID,
        playbackPositionTicks: Int64,
        isFavorite: Bool,
        isPlayed: Bool
    ) {
        // Check if there's already a pending update for this item
        let descriptor = FetchDescriptor<CachedUserProgress>(
            predicate: #Predicate {
                $0.mediaItemId == mediaItemId &&
                    $0.syncStatus == "pending"
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            // Update existing pending record
            existing.playbackPositionTicks = playbackPositionTicks
            existing.isFavorite = isFavorite
            existing.isPlayed = isPlayed
            existing.createdAt = Date()
        } else {
            // Create new pending record
            let progress = CachedUserProgress(
                mediaItemId: mediaItemId,
                serverConfigurationID: serverConfigurationID,
                playbackPositionTicks: playbackPositionTicks,
                isFavorite: isFavorite,
                isPlayed: isPlayed
            )
            modelContext.insert(progress)
        }

        try? modelContext.save()
    }

    /// Gets the count of pending changes
    public func getPendingChangesCount() -> Int {
        let descriptor = FetchDescriptor<CachedUserProgress>(
            predicate: #Predicate { $0.syncStatus == "pending" || $0.syncStatus == "failed" }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Sync Operations

    /// Flushes all pending progress to the server
    public func flushPendingProgress(
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async {
        let configID = serverConfig.id
        let descriptor = FetchDescriptor<CachedUserProgress>(
            predicate: #Predicate {
                $0.serverConfigurationID == configID &&
                    ($0.syncStatus == "pending" || $0.syncStatus == "failed")
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let pendingItems = try? modelContext.fetch(descriptor) else { return }

        for item in pendingItems {
            await syncProgressItem(item, service: service)
        }
    }

    /// Removes pending progress for a server
    public func removePendingProgress(for serverConfigurationID: UUID) {
        let descriptor = FetchDescriptor<CachedUserProgress>(
            predicate: #Predicate { $0.serverConfigurationID == serverConfigurationID }
        )

        guard let items = try? modelContext.fetch(descriptor) else { return }

        for item in items {
            modelContext.delete(item)
        }

        try? modelContext.save()
    }

    // MARK: - Private Methods

    private func syncProgressItem(
        _ item: CachedUserProgress,
        service: JellyfinService
    ) async {
        item.syncStatus = SyncStatus.syncing.rawValue
        item.syncAttempts += 1

        do {
            // Report playback progress to server
            try await service.reportPlaybackProgress(
                itemId: item.mediaItemId,
                positionTicks: item.playbackPositionTicks,
                isPaused: true
            )

            // Update favorite status if changed
            try await service.setFavorite(
                itemId: item.mediaItemId,
                isFavorite: item.isFavorite
            )

            // Update played status if needed
            if item.isPlayed {
                try await service.markAsPlayed(itemId: item.mediaItemId)
            }

            // Success - remove the pending item
            modelContext.delete(item)
            try? modelContext.save()

        } catch {
            // Failed - mark as failed or retry
            if item.syncAttempts >= maxRetryAttempts {
                item.syncStatus = SyncStatus.failed.rawValue
            } else {
                item.syncStatus = SyncStatus.pending.rawValue
            }
            item.lastSyncError = error.localizedDescription
            try? modelContext.save()
        }
    }
}
