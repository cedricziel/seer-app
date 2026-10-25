import JellyfinClient
@testable import SeerApp
import XCTest

final class MediaPlaybackSelectionTests: XCTestCase {
    func testMoviePlaybackUsesRefreshedResumePosition() throws {
        let refreshed = try item(id: "movie", type: "Movie", ticks: 900_000_000)

        let selected = MediaPlaybackSelection.item(
            original: MediaItem(id: refreshed.id, name: "Stale", type: refreshed.type),
            detailedItem: refreshed,
            selectedEpisode: nil
        )

        XCTAssertEqual(selected.userData?.playbackPositionTicks, 900_000_000)
    }

    func testEpisodePlaybackUsesRefreshedResumePosition() throws {
        let refreshed = try item(id: "episode", type: "Episode", ticks: 600_000_000)

        let selected = MediaPlaybackSelection.item(
            original: MediaItem(id: refreshed.id, name: "Stale", type: refreshed.type),
            detailedItem: refreshed,
            selectedEpisode: nil
        )

        XCTAssertEqual(selected.userData?.playbackPositionTicks, 600_000_000)
    }

    func testExplicitSeriesEpisodeTakesPrecedence() throws {
        let series = MediaItem(id: "series", name: "Series", type: .series)
        let episode = try item(id: "episode", type: "Episode", ticks: 300_000_000)

        let selected = MediaPlaybackSelection.item(original: series, detailedItem: nil, selectedEpisode: episode)

        XCTAssertEqual(selected.id, "episode")
        XCTAssertEqual(selected.userData?.playbackPositionTicks, 300_000_000)
    }

    func testPlaybackFallsBackToOriginalBeforeDetailsLoad() throws {
        let original = try item(id: "movie", type: "Movie", ticks: 100_000_000)

        let selected = MediaPlaybackSelection.item(original: original, detailedItem: nil, selectedEpisode: nil)

        XCTAssertEqual(selected, original)
    }

    private func item(id: String, type: String, ticks: Int64) throws -> MediaItem {
        let data = Data("""
        {"Id":"\(id)","Name":"Title","Type":"\(type)","UserData":{"PlaybackPositionTicks":\(ticks)}}
        """.utf8)
        return try JSONDecoder().decode(MediaItem.self, from: data)
    }
}
