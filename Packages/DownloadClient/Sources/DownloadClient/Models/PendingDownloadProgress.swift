import Foundation
import SwiftData

/// Progress awaiting server acknowledgement, retained independently of downloaded files.
@Model
public final class PendingDownloadProgress {
    @Attribute(.unique)
    public var id: UUID
    public var downloadID: UUID
    public var serverID: String
    public var itemID: String
    public var positionTicks: Int64
    public var isWatched: Bool
    public var revision: Int

    public init(downloadID: UUID, serverID: String, itemID: String, positionTicks: Int64, isWatched: Bool) {
        id = UUID()
        self.downloadID = downloadID
        self.serverID = serverID
        self.itemID = itemID
        self.positionTicks = positionTicks
        self.isWatched = isWatched
        revision = 1
    }
}
