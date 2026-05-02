@testable import PlaybackClient
import XCTest

final class MediaSourceExtensionsTests: XCTestCase {
    // MARK: - Stream Filtering

    func testVideoStreams_returnsOnlyVideoStreams() {
        let source = makeSource(streams: [
            stream(type: .video, codec: "h264"),
            stream(type: .audio, codec: "aac"),
            stream(type: .subtitle, codec: "srt")
        ])
        XCTAssertEqual(source.videoStreams.count, 1)
        XCTAssertEqual(source.videoStreams.first?.codec, "h264")
    }

    func testAudioStreams_returnsOnlyAudioStreams() {
        let source = makeSource(streams: [
            stream(type: .video, codec: "h264"),
            stream(type: .audio, codec: "aac"),
            stream(type: .audio, codec: "ac3")
        ])
        XCTAssertEqual(source.audioStreams.count, 2)
    }

    func testSubtitleStreams_returnsOnlySubtitles() {
        let source = makeSource(streams: [
            stream(type: .video, codec: "h264"),
            stream(type: .subtitle, codec: "srt"),
            stream(type: .subtitle, codec: "vtt")
        ])
        XCTAssertEqual(source.subtitleStreams.count, 2)
    }

    func testEmptyStreams_returnsEmptyArrays() {
        let source = makeSource(streams: [])
        XCTAssertTrue(source.videoStreams.isEmpty)
        XCTAssertTrue(source.audioStreams.isEmpty)
        XCTAssertTrue(source.subtitleStreams.isEmpty)
    }

    func testNilStreams_returnsEmptyArrays() {
        let source = makeSource(streams: nil)
        XCTAssertTrue(source.videoStreams.isEmpty)
        XCTAssertTrue(source.audioStreams.isEmpty)
        XCTAssertTrue(source.subtitleStreams.isEmpty)
    }

    // MARK: - Default Streams

    func testDefaultAudioStream_picksDefaultMarkedStream() {
        let source = makeSource(streams: [
            stream(type: .audio, codec: "aac", isDefault: false),
            stream(type: .audio, codec: "ac3", isDefault: true),
            stream(type: .audio, codec: "dts", isDefault: false)
        ])
        XCTAssertEqual(source.defaultAudioStream?.codec, "ac3")
    }

    func testDefaultAudioStream_fallsBackToFirst_whenNoneDefault() {
        let source = makeSource(streams: [
            stream(type: .audio, codec: "aac", isDefault: false),
            stream(type: .audio, codec: "ac3", isDefault: false)
        ])
        XCTAssertEqual(source.defaultAudioStream?.codec, "aac")
    }

    func testDefaultAudioStream_noAudio_returnsNil() {
        let source = makeSource(streams: [stream(type: .video, codec: "h264")])
        XCTAssertNil(source.defaultAudioStream)
    }

    func testDefaultSubtitleStream_picksDefaultMarkedStream() {
        let source = makeSource(streams: [
            stream(type: .subtitle, codec: "srt", isDefault: false),
            stream(type: .subtitle, codec: "vtt", isDefault: true)
        ])
        XCTAssertEqual(source.defaultSubtitleStream?.codec, "vtt")
    }

    func testDefaultSubtitleStream_noDefault_returnsNil() {
        let source = makeSource(streams: [
            stream(type: .subtitle, codec: "srt", isDefault: false)
        ])
        // Subtitle default behavior: explicit nil if none marked default
        XCTAssertNil(source.defaultSubtitleStream)
    }

    // MARK: - Runtime

    func testRuntimeSeconds_oneHour() throws {
        let source = makeSource(streams: nil, runTimeTicks: 36_000_000_000)
        let seconds = try XCTUnwrap(source.runtimeSeconds)
        XCTAssertEqual(seconds, 3600.0, accuracy: 0.001)
    }

    func testRuntimeSeconds_nilTicks_returnsNil() {
        let source = makeSource(streams: nil, runTimeTicks: nil)
        XCTAssertNil(source.runtimeSeconds)
    }

    // MARK: - StreamType decoding falls back to unknown

    func testStreamType_unknownValue_decodesToUnknown() throws {
        let json = Data("""
        {
          "Index": 0,
          "Type": "Magic",
          "Codec": "x"
        }
        """.utf8)
        let stream = try JSONDecoder().decode(MediaStream.self, from: json)
        XCTAssertEqual(stream.type, .unknown)
    }

    // MARK: - Helpers

    private func makeSource(
        streams: [MediaStream]?,
        runTimeTicks: Int64? = nil
    ) -> MediaSource {
        MediaSource(
            id: "test",
            mediaStreams: streams,
            runTimeTicks: runTimeTicks
        )
    }

    private func stream(
        type: MediaStream.StreamType,
        codec: String,
        isDefault: Bool? = nil
    ) -> MediaStream {
        MediaStream(
            index: Int.random(in: 0 ... 1000),
            type: type,
            codec: codec,
            isDefault: isDefault
        )
    }
}
