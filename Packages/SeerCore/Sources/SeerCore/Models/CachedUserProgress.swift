import Foundation
import SwiftData

/// Pending sync queue for user progress changes
/// Tracks local changes that need to be synced to the server
@Model
public final class CachedUserProgress {
    // Note: CloudKit doesn't support unique constraints
    public var id: UUID = UUID()
    public var mediaItemId: String = ""
    public var serverConfigurationID: UUID = UUID()
    public var playbackPositionTicks: Int64 = 0
    public var isFavorite: Bool = false
    public var isPlayed: Bool = false
    public var createdAt: Date = Date()

    /// Sync status: pending, syncing, failed
    public var syncStatus: String = "pending"

    /// Number of sync attempts (for retry logic)
    public var syncAttempts: Int = 0

    /// Last error message if sync failed
    public var lastSyncError: String?

    public init(
        id: UUID = UUID(),
        mediaItemId: String,
        serverConfigurationID: UUID,
        playbackPositionTicks: Int64,
        isFavorite: Bool = false,
        isPlayed: Bool = false,
        createdAt: Date = Date(),
        syncStatus: String = "pending",
        syncAttempts: Int = 0,
        lastSyncError: String? = nil
    ) {
        self.id = id
        self.mediaItemId = mediaItemId
        self.serverConfigurationID = serverConfigurationID
        self.playbackPositionTicks = playbackPositionTicks
        self.isFavorite = isFavorite
        self.isPlayed = isPlayed
        self.createdAt = createdAt
        self.syncStatus = syncStatus
        self.syncAttempts = syncAttempts
        self.lastSyncError = lastSyncError
    }
}

// MARK: - SyncStatus Enum

public enum SyncStatus: String, Sendable {
    case pending
    case syncing
    case failed
    case completed
}
