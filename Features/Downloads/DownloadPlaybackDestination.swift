import DownloadClient
import Foundation
import JellyfinClient

struct DownloadPlaybackDestination: Identifiable {
    let id: UUID
    let serverID: String
    let item: MediaItem
    let startPositionTicks: Int64

    init?(download: Download) {
        guard download.state == .completed, download.relativePath != nil,
              let type = MediaItem.MediaType(rawValue: download.mediaType),
              type == .movie || type == .episode
        else { return nil }

        id = download.id
        serverID = download.serverID
        item = MediaItem(
            id: download.itemID,
            name: download.name,
            year: download.year,
            runTimeTicks: download.runTimeTicks,
            type: type,
            seriesName: download.seriesName,
            indexNumber: download.episodeNumber,
            parentIndexNumber: download.seasonNumber
        )
        startPositionTicks = download.isWatched ? 0 : download.playbackPositionTicks
    }
}
