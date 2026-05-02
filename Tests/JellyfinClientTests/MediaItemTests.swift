@testable import JellyfinClient
import XCTest

final class MediaItemTests: XCTestCase {
    // MARK: - runtimeMinutes

    func testRuntimeMinutes_nilTicks_returnsNil() {
        let item = makeItem(runTimeTicks: nil)
        XCTAssertNil(item.runtimeMinutes)
    }

    func testRuntimeMinutes_oneHour_returns60() {
        // 1 hour = 36_000_000_000 ticks (10M ticks/sec * 3600s)
        let item = makeItem(runTimeTicks: 36_000_000_000)
        XCTAssertEqual(item.runtimeMinutes, 60)
    }

    func testRuntimeMinutes_twoHoursFifteenMinutes_returns135() {
        // 81_000_000_000 ticks = 2h15m
        let item = makeItem(runTimeTicks: 81_000_000_000)
        XCTAssertEqual(item.runtimeMinutes, 135)
    }

    func testRuntimeMinutes_lessThanOneMinute_returnsZero() {
        let item = makeItem(runTimeTicks: 100_000_000) // 10 seconds
        XCTAssertEqual(item.runtimeMinutes, 0)
    }

    // MARK: - formattedRuntime

    func testFormattedRuntime_nilTicks_returnsNil() {
        XCTAssertNil(makeItem(runTimeTicks: nil).formattedRuntime)
    }

    func testFormattedRuntime_underOneHour_returnsMinutes() {
        let item = makeItem(runTimeTicks: 27_000_000_000) // 45 min
        XCTAssertEqual(item.formattedRuntime, "45m")
    }

    func testFormattedRuntime_exactlyOneHour_returnsHoursAndMinutes() {
        let item = makeItem(runTimeTicks: 36_000_000_000) // 1h
        XCTAssertEqual(item.formattedRuntime, "1h 0m")
    }

    func testFormattedRuntime_overOneHour_returnsHoursAndMinutes() {
        let item = makeItem(runTimeTicks: 81_000_000_000) // 2h15m
        XCTAssertEqual(item.formattedRuntime, "2h 15m")
    }

    // MARK: - isPlayable

    func testIsPlayable_movie_returnsTrue() {
        XCTAssertTrue(makeItem(type: .movie).isPlayable)
    }

    func testIsPlayable_episode_returnsTrue() {
        XCTAssertTrue(makeItem(type: .episode).isPlayable)
    }

    func testIsPlayable_series_returnsFalse() {
        XCTAssertFalse(makeItem(type: .series).isPlayable)
    }

    func testIsPlayable_season_returnsFalse() {
        XCTAssertFalse(makeItem(type: .season).isPlayable)
    }

    func testIsPlayable_boxSet_returnsFalse() {
        XCTAssertFalse(makeItem(type: .boxSet).isPlayable)
    }

    // MARK: - formattedVideoInfo

    func testFormattedVideoInfo_nilCodec_returnsNil() {
        let item = makeItem(videoCodec: nil)
        XCTAssertNil(item.formattedVideoInfo)
    }

    func testFormattedVideoInfo_codecOnly_returnsUppercased() {
        let item = makeItem(videoCodec: "h264")
        XCTAssertEqual(item.formattedVideoInfo, "H264")
    }

    func testFormattedVideoInfo_codecAndResolution_combinesWithSpace() {
        let item = makeItem(videoCodec: "hevc", videoResolution: "1080p")
        XCTAssertEqual(item.formattedVideoInfo, "HEVC 1080p")
    }

    // MARK: - formattedAudioInfo

    func testFormattedAudioInfo_nilCodec_returnsNil() {
        XCTAssertNil(makeItem(audioCodec: nil).formattedAudioInfo)
    }

    func testFormattedAudioInfo_monoChannels_returnsMono() {
        let item = makeItem(audioCodec: "aac", audioChannels: 1)
        XCTAssertEqual(item.formattedAudioInfo, "AAC Mono")
    }

    func testFormattedAudioInfo_stereoChannels_returnsStereo() {
        let item = makeItem(audioCodec: "aac", audioChannels: 2)
        XCTAssertEqual(item.formattedAudioInfo, "AAC Stereo")
    }

    func testFormattedAudioInfo_sixChannels_returns51() {
        let item = makeItem(audioCodec: "ac3", audioChannels: 6)
        XCTAssertEqual(item.formattedAudioInfo, "AC3 5.1")
    }

    func testFormattedAudioInfo_eightChannels_returns71() {
        let item = makeItem(audioCodec: "dts", audioChannels: 8)
        XCTAssertEqual(item.formattedAudioInfo, "DTS 7.1")
    }

    func testFormattedAudioInfo_fourChannels_returnsCh() {
        let item = makeItem(audioCodec: "ac3", audioChannels: 4)
        XCTAssertEqual(item.formattedAudioInfo, "AC3 4ch")
    }

    func testFormattedAudioInfo_codecOnly_returnsUppercased() {
        let item = makeItem(audioCodec: "aac", audioChannels: nil)
        XCTAssertEqual(item.formattedAudioInfo, "AAC")
    }

    // MARK: - formattedContainer

    func testFormattedContainer_returnsUppercased() {
        let item = makeItem(container: "mp4")
        XCTAssertEqual(item.formattedContainer, "MP4")
    }

    func testFormattedContainer_nilContainer_returnsNil() {
        let item = makeItem(container: nil)
        XCTAssertNil(item.formattedContainer)
    }

    // MARK: - Decoding from JSON with MediaSources

    func testDecode_extractsContainerAndCodecsFromMediaSources() throws {
        let json = Data("""
        {
          "Id": "abc",
          "Name": "Test Movie",
          "Type": "Movie",
          "MediaSources": [
            {
              "Container": "mkv",
              "MediaStreams": [
                {"Type": "Video", "Codec": "h264", "Width": 1920, "Height": 1080},
                {"Type": "Audio", "Codec": "aac", "Channels": 6}
              ]
            }
          ]
        }
        """.utf8)

        let item = try JSONDecoder().decode(MediaItem.self, from: json)

        XCTAssertEqual(item.container, "mkv")
        XCTAssertEqual(item.videoCodec, "h264")
        XCTAssertEqual(item.videoResolution, "1080p")
        XCTAssertEqual(item.audioCodec, "aac")
        XCTAssertEqual(item.audioChannels, 6)
    }

    func testDecode_resolutionMappings() throws {
        // Test the resolution boundary handling via decoded items
        for (height, expected) in [
            (240, "SD"),
            (480, "480p"),
            (720, "720p"),
            (1080, "1080p"),
            (2160, "4K"),
            (4320, "4K")
        ] {
            let json = Data("""
            {
              "Id": "abc",
              "Name": "Test",
              "Type": "Movie",
              "MediaSources": [
                {
                  "Container": "mp4",
                  "MediaStreams": [
                    {"Type": "Video", "Codec": "h264", "Width": 1, "Height": \(height)}
                  ]
                }
              ]
            }
            """.utf8)
            let item = try JSONDecoder().decode(MediaItem.self, from: json)
            XCTAssertEqual(item.videoResolution, expected, "Height \(height) should map to \(expected)")
        }
    }

    func testDecode_unknownMediaType_fallsBackToUnknown() throws {
        let json = Data("""
        {"Id": "abc", "Name": "Test", "Type": "SomethingNew"}
        """.utf8)
        let item = try JSONDecoder().decode(MediaItem.self, from: json)
        XCTAssertEqual(item.type, .unknown)
    }

    func testDecode_directProperties_takePrecedenceOverMediaSources() throws {
        let json = Data("""
        {
          "Id": "abc",
          "Name": "Test",
          "Type": "Movie",
          "Container": "mp4",
          "VideoCodec": "hevc",
          "MediaSources": [
            {"Container": "mkv", "MediaStreams": [{"Type": "Video", "Codec": "h264"}]}
          ]
        }
        """.utf8)

        let item = try JSONDecoder().decode(MediaItem.self, from: json)

        // Direct top-level properties should win
        XCTAssertEqual(item.container, "mp4")
        XCTAssertEqual(item.videoCodec, "hevc")
    }

    // MARK: - Round-trip

    func testEncodeDecode_roundTrip_preservesData() throws {
        let original = makeItem(
            id: "movie-1",
            type: .movie,
            videoCodec: "hevc",
            audioCodec: "ac3",
            videoResolution: "4K",
            audioChannels: 6,
            runTimeTicks: 72_000_000_000,
            container: "mp4"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.videoCodec, original.videoCodec)
        XCTAssertEqual(decoded.audioCodec, original.audioCodec)
        XCTAssertEqual(decoded.videoResolution, original.videoResolution)
        XCTAssertEqual(decoded.audioChannels, original.audioChannels)
        XCTAssertEqual(decoded.container, original.container)
        XCTAssertEqual(decoded.runTimeTicks, original.runTimeTicks)
    }

    // MARK: - Helpers

    private func makeItem(
        id: String = "test-id",
        type: MediaItem.MediaType = .movie,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoResolution: String? = nil,
        audioChannels: Int? = nil,
        runTimeTicks: Int64? = nil,
        container: String? = nil
    ) -> MediaItem {
        MediaItem(
            id: id,
            name: "Test",
            runTimeTicks: runTimeTicks,
            type: type,
            container: container,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            videoResolution: videoResolution,
            audioChannels: audioChannels
        )
    }
}
