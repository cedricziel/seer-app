import Foundation

/// A persisted playback update. Acknowledgement applies only to this revision.
public struct DownloadPlaybackProgress: Sendable {
    public let id: UUID
    public let downloadID: UUID
    public let serverID: String
    public let itemID: String
    public let positionTicks: Int64
    public let isWatched: Bool
    public let revision: Int
}
