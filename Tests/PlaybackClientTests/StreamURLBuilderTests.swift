@testable import PlaybackClient
import XCTest

final class StreamURLBuilderTests: XCTestCase {
    let serverURL = URL(string: "https://jellyfin.example.com")!
    let accessToken = "test-access-token"
    let deviceID = "test-device-id"

    // MARK: - iOS Compatibility Tests

    func testIsIOSCompatible_mp4H264AAC_returnsTrue() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac"
        )

        XCTAssertTrue(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_movHevcAAC_returnsTrue() {
        let mediaSource = createMediaSource(
            container: "mov",
            videoCodec: "hevc",
            audioCodec: "aac"
        )

        XCTAssertTrue(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_m4vH264AC3_returnsTrue() {
        let mediaSource = createMediaSource(
            container: "m4v",
            videoCodec: "h264",
            audioCodec: "ac3"
        )

        XCTAssertTrue(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_mkvH264AAC_returnsFalse() {
        // MKV container is not iOS-compatible even if codecs are
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "aac"
        )

        XCTAssertFalse(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_mp4VP9AAC_returnsFalse() {
        // VP9 video codec is not iOS-compatible
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "vp9",
            audioCodec: "aac"
        )

        XCTAssertFalse(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_mp4H264Opus_returnsFalse() {
        // Opus audio codec is not iOS-compatible
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "opus"
        )

        XCTAssertFalse(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    func testIsIOSCompatible_aviH264AAC_returnsFalse() {
        // AVI container is not iOS-compatible
        let mediaSource = createMediaSource(
            container: "avi",
            videoCodec: "h264",
            audioCodec: "aac"
        )

        XCTAssertFalse(StreamURLBuilder.isIOSCompatible(mediaSource: mediaSource))
    }

    // MARK: - Container Compatibility Tests

    func testIsContainerCompatible_mp4_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isContainerCompatible("mp4"))
    }

    func testIsContainerCompatible_m4v_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isContainerCompatible("m4v"))
    }

    func testIsContainerCompatible_mov_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isContainerCompatible("mov"))
    }

    func testIsContainerCompatible_mkv_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isContainerCompatible("mkv"))
    }

    func testIsContainerCompatible_avi_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isContainerCompatible("avi"))
    }

    func testIsContainerCompatible_webm_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isContainerCompatible("webm"))
    }

    func testIsContainerCompatible_caseInsensitive() {
        XCTAssertTrue(StreamURLBuilder.isContainerCompatible("MP4"))
        XCTAssertTrue(StreamURLBuilder.isContainerCompatible("MOV"))
        XCTAssertFalse(StreamURLBuilder.isContainerCompatible("MKV"))
    }

    // MARK: - Video Codec Compatibility Tests

    func testIsVideoCodecCompatible_h264_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("h264"))
    }

    func testIsVideoCodecCompatible_hevc_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("hevc"))
    }

    func testIsVideoCodecCompatible_h265_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("h265"))
    }

    func testIsVideoCodecCompatible_avc_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("avc"))
    }

    func testIsVideoCodecCompatible_avc1_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("avc1"))
    }

    func testIsVideoCodecCompatible_vp9_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isVideoCodecCompatible("vp9"))
    }

    func testIsVideoCodecCompatible_av1_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isVideoCodecCompatible("av1"))
    }

    func testIsVideoCodecCompatible_caseInsensitive() {
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("H264"))
        XCTAssertTrue(StreamURLBuilder.isVideoCodecCompatible("HEVC"))
    }

    // MARK: - Audio Codec Compatibility Tests

    func testIsAudioCodecCompatible_aac_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("aac"))
    }

    func testIsAudioCodecCompatible_ac3_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("ac3"))
    }

    func testIsAudioCodecCompatible_eac3_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("eac3"))
    }

    func testIsAudioCodecCompatible_mp3_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("mp3"))
    }

    func testIsAudioCodecCompatible_alac_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("alac"))
    }

    func testIsAudioCodecCompatible_flac_returnsTrue() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("flac"))
    }

    func testIsAudioCodecCompatible_opus_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isAudioCodecCompatible("opus"))
    }

    func testIsAudioCodecCompatible_dts_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isAudioCodecCompatible("dts"))
    }

    func testIsAudioCodecCompatible_truehd_returnsFalse() {
        XCTAssertFalse(StreamURLBuilder.isAudioCodecCompatible("truehd"))
    }

    func testIsAudioCodecCompatible_caseInsensitive() {
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("AAC"))
        XCTAssertTrue(StreamURLBuilder.isAudioCodecCompatible("AC3"))
    }

    // MARK: - Playback Method Selection Tests

    func testBuildStreamInfo_compatibleFormat_supportsDirectPlay_returnsDirectPlay() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsDirectStream: true,
            supportsTranscoding: true
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .directPlay)
        XCTAssertTrue(streamInfo?.url.absoluteString.contains("/stream") ?? false)
    }

    func testBuildStreamInfo_compatibleFormat_noDirectPlay_supportsDirectStream_returnsDirectStream() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: false,
            supportsDirectStream: true,
            supportsTranscoding: true,
            directStreamUrl: "/Videos/test-id/stream.mp4"
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .directStream)
    }

    func testBuildStreamInfo_incompatibleFormat_serverProvidesTranscodingUrl_usesProvidedUrl() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "ac3",
            supportsDirectPlay: true,
            supportsDirectStream: true,
            supportsTranscoding: true,
            transcodingUrl: "/Videos/test-id/master.m3u8?existingParams=value"
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .hls)
        XCTAssertTrue(streamInfo?.url.absoluteString.contains("existingParams=value") ?? false)
    }

    func testBuildStreamInfo_incompatibleFormat_noTranscodingUrl_supportsTranscoding_buildsHLSUrl() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "ac3",
            supportsDirectPlay: true,
            supportsDirectStream: true,
            supportsTranscoding: true,
            transcodingUrl: nil // Server didn't provide a transcoding URL
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .hls)

        // Verify the URL contains required parameters
        let urlString = streamInfo?.url.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("master.m3u8"), "URL should use master.m3u8 endpoint")
        XCTAssertTrue(urlString.contains("mediaSourceId="), "URL should include mediaSourceId")
        XCTAssertTrue(urlString.contains("videoCodec=h264"), "URL should specify h264 video codec")
        XCTAssertTrue(urlString.contains("audioCodec=aac"), "URL should specify aac audio codec")
    }

    func testBuildStreamInfo_incompatibleFormat_noTranscodingSupport_fallsBackToDirectPlay() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "ac3",
            supportsDirectPlay: true,
            supportsDirectStream: true,
            supportsTranscoding: false // Server doesn't support transcoding
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .directPlay)
    }

    // MARK: - HLS URL Building Tests

    func testBuildHLSURL_includesAllRequiredParameters() {
        let hlsURL = StreamURLBuilder.buildHLSURL(
            itemId: "item-123",
            mediaSourceId: "source-456",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        let urlString = hlsURL.absoluteString

        XCTAssertTrue(urlString.contains("/Videos/item-123/master.m3u8"))
        XCTAssertTrue(urlString.contains("mediaSourceId=source-456"))
        XCTAssertTrue(urlString.contains("api_key=\(accessToken)"))
        XCTAssertTrue(urlString.contains("DeviceId=\(deviceID)"))
        XCTAssertTrue(urlString.contains("videoCodec=h264"))
        XCTAssertTrue(urlString.contains("audioCodec=aac"))
        XCTAssertTrue(urlString.contains("segmentContainer=ts"))
    }

    func testBuildHLSURL_includesAudioStreamIndex_whenProvided() {
        let hlsURL = StreamURLBuilder.buildHLSURL(
            itemId: "item-123",
            mediaSourceId: "source-456",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            audioStreamIndex: 2
        )

        XCTAssertTrue(hlsURL.absoluteString.contains("AudioStreamIndex=2"))
    }

    func testBuildHLSURL_includesSubtitleStreamIndex_whenProvided() {
        let hlsURL = StreamURLBuilder.buildHLSURL(
            itemId: "item-123",
            mediaSourceId: "source-456",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            subtitleStreamIndex: 3
        )

        XCTAssertTrue(hlsURL.absoluteString.contains("SubtitleStreamIndex=3"))
    }

    // MARK: - DirectPlay URL Building Tests

    func testBuildDirectPlayURL_usesCorrectFormat() {
        let directPlayURL = StreamURLBuilder.buildDirectPlayURL(
            mediaSourceId: "media-123",
            serverURL: serverURL
        )

        XCTAssertEqual(
            directPlayURL.absoluteString,
            "https://jellyfin.example.com/Videos/media-123/stream"
        )
    }

    // MARK: - Auth Headers Tests

    func testBuildAuthHeaders_includesAuthorizationHeader() {
        let headers = StreamURLBuilder.buildAuthHeaders(
            accessToken: accessToken,
            deviceID: deviceID
        )

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertTrue(headers["Authorization"]?.contains("Token=\"\(accessToken)\"") ?? false)
        XCTAssertTrue(headers["Authorization"]?.contains("DeviceId=\"\(deviceID)\"") ?? false)
        XCTAssertEqual(headers["Accept"], "application/json")
    }

    // MARK: - Edge Cases

    func testBuildStreamInfo_nilContainer_returnsStreamInfo() {
        let mediaSource = createMediaSource(
            container: nil,
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: mediaSource,
            playSessionId: "test-session",
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        // Should fall back to HLS since container is unknown
        XCTAssertNotNil(streamInfo)
        XCTAssertEqual(streamInfo?.type, .hls)
    }

    // MARK: - Download URL Building Tests

    func testBuildDownloadURL_compatibleFormat_originalQuality_returnsDirectDownload() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .original
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isTranscoded ?? true)
        XCTAssertTrue(result?.url.absoluteString.contains("/Download") ?? false)
    }

    func testBuildDownloadURL_compatibleFormat_restrictedQuality_returnsTranscoded() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .high
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isTranscoded ?? false)
        XCTAssertTrue(result?.url.absoluteString.contains("master.m3u8") ?? false)
        XCTAssertTrue(result?.url.absoluteString.contains("maxWidth=1920") ?? false)
    }

    func testBuildDownloadURL_incompatibleFormat_supportsTranscoding_returnsTranscoded() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "ac3",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .original
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isTranscoded ?? false)
        XCTAssertTrue(result?.url.absoluteString.contains("master.m3u8") ?? false)
        XCTAssertTrue(result?.url.absoluteString.contains("videoCodec=h264") ?? false)
        XCTAssertTrue(result?.url.absoluteString.contains("audioCodec=aac") ?? false)
    }

    func testBuildDownloadURL_incompatibleFormat_withQuality_appliesQualitySettings() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "hevc",
            audioCodec: "dts",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .medium
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isTranscoded ?? false)

        let urlString = result?.url.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("maxWidth=1280"), "Medium quality should have maxWidth=1280")
        XCTAssertTrue(urlString.contains("videoBitRate=4000000"), "Medium quality should have bitrate=4000000")
    }

    func testBuildDownloadURL_incompatibleFormat_noTranscodingSupport_fallsBackToDirectDownload() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "ac3",
            supportsDirectPlay: true,
            supportsTranscoding: false // Server doesn't support transcoding
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .original
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isTranscoded ?? true)
        XCTAssertTrue(result?.url.absoluteString.contains("/Download") ?? false)
    }

    func testBuildDownloadURL_noPlaybackMethodAvailable_returnsNil() {
        let mediaSource = createMediaSource(
            container: "mkv",
            videoCodec: "vp9",
            audioCodec: "opus",
            supportsDirectPlay: false,
            supportsDirectStream: false,
            supportsTranscoding: false
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .original
        )

        XCTAssertNil(result)
    }

    func testBuildDownloadURL_lowQuality_appliesCorrectSettings() {
        let mediaSource = createMediaSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            supportsDirectPlay: true,
            supportsTranscoding: true
        )

        let result = StreamURLBuilder.buildDownloadURL(
            mediaSource: mediaSource,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            quality: .low
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isTranscoded ?? false)

        let urlString = result?.url.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("maxWidth=854"), "Low quality should have maxWidth=854")
        XCTAssertTrue(urlString.contains("videoBitRate=1500000"), "Low quality should have bitrate=1500000")
    }

    func testDownloadQualitySettings_staticValues() {
        // Test that static quality settings have correct values
        XCTAssertNil(StreamURLBuilder.DownloadQualitySettings.original.maxWidth)
        XCTAssertNil(StreamURLBuilder.DownloadQualitySettings.original.maxBitrate)

        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.high.maxWidth, 1920)
        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.high.maxBitrate, 8_000_000)

        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.medium.maxWidth, 1280)
        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.medium.maxBitrate, 4_000_000)

        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.low.maxWidth, 854)
        XCTAssertEqual(StreamURLBuilder.DownloadQualitySettings.low.maxBitrate, 1_500_000)
    }

    // MARK: - Helpers

    private func createMediaSource(
        id: String = "test-media-source-id",
        container: String?,
        videoCodec: String?,
        audioCodec: String?,
        supportsDirectPlay: Bool = true,
        supportsDirectStream: Bool = true,
        supportsTranscoding: Bool = true,
        directStreamUrl: String? = nil,
        transcodingUrl: String? = nil
    ) -> MediaSource {
        var mediaStreams: [MediaStream] = []

        if let videoCodec {
            mediaStreams.append(MediaStream(
                index: 0,
                type: .video,
                codec: videoCodec,
                language: nil,
                displayTitle: "Video",
                title: nil,
                isDefault: true,
                isExternal: false,
                deliveryUrl: nil,
                width: 1920,
                height: 1080,
                bitRate: 5_000_000,
                channels: nil,
                sampleRate: nil
            ))
        }

        if let audioCodec {
            mediaStreams.append(MediaStream(
                index: 1,
                type: .audio,
                codec: audioCodec,
                language: "eng",
                displayTitle: "English",
                title: nil,
                isDefault: true,
                isExternal: false,
                deliveryUrl: nil,
                width: nil,
                height: nil,
                bitRate: 320_000,
                channels: 2,
                sampleRate: 48000
            ))
        }

        return MediaSource(
            id: id,
            name: "Test Media",
            path: "/path/to/media",
            container: container,
            size: 1_000_000_000,
            bitrate: 5_320_000,
            supportsDirectPlay: supportsDirectPlay,
            supportsDirectStream: supportsDirectStream,
            supportsTranscoding: supportsTranscoding,
            directStreamUrl: directStreamUrl,
            transcodingUrl: transcodingUrl,
            transcodingSubProtocol: transcodingUrl != nil ? "hls" : nil,
            transcodingContainer: transcodingUrl != nil ? "ts" : nil,
            mediaStreams: mediaStreams,
            runTimeTicks: 72_000_000_000 // 2 hours
        )
    }
}
