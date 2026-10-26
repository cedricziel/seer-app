import Foundation
import SwiftData

public extension DownloadStore {
    /// Returns unsynchronized progress for one server, including saved watched status.
    func pendingPlaybackProgress(serverID: String) throws -> [DownloadPlaybackProgress] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PendingDownloadProgress>(predicate: #Predicate { $0.serverID == serverID })
        return try context.fetch(descriptor).map {
            DownloadPlaybackProgress(
                id: $0.id,
                downloadID: $0.downloadID,
                serverID: $0.serverID,
                itemID: $0.itemID,
                positionTicks: $0.positionTicks,
                isWatched: $0.isWatched,
                revision: $0.revision
            )
        }
    }

    /// Sends pending updates once per server. Failed or superseded updates remain pending.
    func syncPlaybackProgress(
        serverID: String,
        report: @Sendable (DownloadPlaybackProgress) async throws -> Void
    ) async {
        guard !syncingPlaybackServers.contains(serverID) else { return }
        syncingPlaybackServers.insert(serverID)
        defer { syncingPlaybackServers.remove(serverID) }
        guard let pending = try? pendingPlaybackProgress(serverID: serverID) else { return }
        for progress in pending {
            do {
                try await report(progress)
                try acknowledgePlaybackProgress(progress)
            } catch {
                continue
            }
        }
    }
}

private extension DownloadStore {
    func acknowledgePlaybackProgress(_ progress: DownloadPlaybackProgress) throws {
        let context = ModelContext(modelContainer)
        let progressID = progress.id
        let descriptor = FetchDescriptor<PendingDownloadProgress>(predicate: #Predicate { $0.id == progressID })
        guard let pending = try context.fetch(descriptor).first, pending.revision == progress.revision else { return }
        context.delete(pending)
        try context.save()
    }
}

extension DownloadStore {
    func queuePlaybackProgress(download: Download, context: ModelContext) throws {
        let serverID = download.serverID
        let itemID = download.itemID
        let descriptor = FetchDescriptor<PendingDownloadProgress>(predicate: #Predicate {
            $0.serverID == serverID && $0.itemID == itemID
        })
        if let pending = try context.fetch(descriptor).first {
            pending.downloadID = download.id
            pending.positionTicks = download.playbackPositionTicks
            pending.isWatched = download.isWatched
            pending.revision += 1
        } else {
            context.insert(PendingDownloadProgress(
                downloadID: download.id,
                serverID: download.serverID,
                itemID: download.itemID,
                positionTicks: download.playbackPositionTicks,
                isWatched: download.isWatched
            ))
        }
    }
}
