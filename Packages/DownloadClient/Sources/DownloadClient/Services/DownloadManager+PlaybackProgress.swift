import Foundation

public extension DownloadManager {
    /// Retries saved playback updates with credentials belonging to the specified server.
    func syncPlaybackProgress(
        serverID: String,
        report: @Sendable (DownloadPlaybackProgress) async throws -> Void
    ) async {
        await store.syncPlaybackProgress(serverID: serverID, report: report)
    }
}
