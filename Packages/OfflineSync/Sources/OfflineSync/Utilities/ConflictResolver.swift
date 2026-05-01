import Foundation
import SeerCore

/// Resolves conflicts between local cached data and server data
/// Strategy: Server wins for metadata, merge progress (take higher value)
public struct ConflictResolver {
    public init() {}

    /// Resolves conflicts for user progress data
    /// - Parameters:
    ///   - local: Local cached progress
    ///   - serverPosition: Server's playback position in ticks
    ///   - serverIsFavorite: Server's favorite status
    ///   - serverIsPlayed: Server's played status
    /// - Returns: Resolved progress values
    public func resolveProgress(
        local: CachedUserProgress?,
        serverPosition: Int64?,
        serverIsFavorite: Bool?,
        serverIsPlayed: Bool?
    ) -> ResolvedProgress {
        // Take the higher playback position (more progress)
        let resolvedPosition: Int64 = if let localPos = local?.playbackPositionTicks, let serverPos = serverPosition {
            max(localPos, serverPos)
        } else {
            local?.playbackPositionTicks ?? serverPosition ?? 0
        }

        // For favorite/played: if there's a pending local change, keep it; otherwise use server
        let resolvedFavorite: Bool = if let local, local.syncStatus == SyncStatus.pending.rawValue {
            local.isFavorite
        } else {
            serverIsFavorite ?? false
        }

        let resolvedPlayed: Bool = if let local, local.syncStatus == SyncStatus.pending.rawValue {
            local.isPlayed
        } else {
            serverIsPlayed ?? false
        }

        return ResolvedProgress(
            playbackPositionTicks: resolvedPosition,
            isFavorite: resolvedFavorite,
            isPlayed: resolvedPlayed
        )
    }
}

/// Resolved progress after conflict resolution
public struct ResolvedProgress: Sendable {
    public let playbackPositionTicks: Int64
    public let isFavorite: Bool
    public let isPlayed: Bool
}
