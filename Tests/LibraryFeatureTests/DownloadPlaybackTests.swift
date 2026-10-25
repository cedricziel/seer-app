import DownloadClient
@testable import SeerApp
import XCTest

final class DownloadPlaybackTests: XCTestCase {
    func testCompletedMovieOpensUsingStoredIdentityWithoutLibraryData() throws {
        let download = makeDownload(mediaType: "Movie")
        download.state = .completed
        download.relativePath = "server-a/Movie/item.mp4"
        download.playbackPositionTicks = 420_000_000

        let destination = try XCTUnwrap(DownloadPlaybackDestination(download: download))

        XCTAssertEqual(destination.id, download.id)
        XCTAssertEqual(destination.serverID, "server-a")
        XCTAssertEqual(destination.item.id, "item")
        XCTAssertEqual(destination.item.name, "Downloaded title")
        XCTAssertEqual(destination.item.type, .movie)
        XCTAssertEqual(destination.startPositionTicks, 420_000_000)
    }

    func testCompletedEpisodeRetainsEpisodeMetadata() throws {
        let download = makeDownload(mediaType: "Episode")
        download.state = .completed
        download.relativePath = "server-a/Episode/item.mp4"

        let destination = try XCTUnwrap(DownloadPlaybackDestination(download: download))

        XCTAssertEqual(destination.item.type, .episode)
        XCTAssertEqual(destination.item.seriesName, "Series")
        XCTAssertEqual(destination.item.parentIndexNumber, 2)
        XCTAssertEqual(destination.item.indexNumber, 3)
        XCTAssertEqual(destination.item.runTimeTicks, 2_400_000_000)
    }

    func testIncompleteDownloadCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.relativePath = "server-a/Movie/item.mp4"

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testPausedDownloadCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.state = .paused
        download.relativePath = "server-a/Movie/item.mp4"

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testFailedDownloadCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.state = .failed
        download.relativePath = "server-a/Movie/item.mp4"

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testWaitingForWiFiDownloadCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.state = .waitingForWiFi
        download.relativePath = "server-a/Movie/item.mp4"

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testDownloadingItemCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.state = .downloading
        download.relativePath = "server-a/Movie/item.mp4"

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testCompletedDownloadWithoutFilePathCannotOpenPlayer() {
        let download = makeDownload(mediaType: "Movie")
        download.state = .completed

        XCTAssertNil(DownloadPlaybackDestination(download: download))
    }

    func testWatchedDownloadStartsFromBeginning() throws {
        let download = makeDownload(mediaType: "Movie")
        download.state = .completed
        download.relativePath = "server-a/Movie/item.mp4"
        download.playbackPositionTicks = 2_400_000_000
        download.isWatched = true

        let destination = try XCTUnwrap(DownloadPlaybackDestination(download: download))

        XCTAssertEqual(destination.startPositionTicks, 0)
    }

    private func makeDownload(mediaType: String) -> Download {
        Download(
            serverID: "server-a",
            itemID: "item",
            mediaSourceID: "source",
            name: "Downloaded title",
            mediaType: mediaType,
            seriesName: "Series",
            seasonNumber: 2,
            episodeNumber: 3,
            runTimeTicks: 2_400_000_000
        )
    }
}
