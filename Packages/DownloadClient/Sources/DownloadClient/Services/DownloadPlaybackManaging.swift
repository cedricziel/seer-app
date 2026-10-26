import Foundation

/// Provides local media and saves its per-device playback progress.
@MainActor
public protocol DownloadPlaybackManaging: AnyObject {
    func download(forItemID itemID: String, serverID: String) async -> Download?
    func localFileURL(forItemID itemID: String, serverID: String) async -> URL?
    func updatePlaybackPosition(downloadID: UUID, positionTicks: Int64, isWatched: Bool) async throws
}

extension DownloadManager: DownloadPlaybackManaging {}
