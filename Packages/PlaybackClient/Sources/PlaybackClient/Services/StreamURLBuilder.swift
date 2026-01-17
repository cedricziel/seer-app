import Foundation
import os.log

private let logger = Logger(subsystem: "com.seer.PlaybackClient", category: "StreamURLBuilder")

/// Builds authenticated stream URLs for Jellyfin media
public enum StreamURLBuilder {
    // MARK: - iOS Compatibility Constants

    /// Container formats that iOS can play natively
    private static let iOSCompatibleContainers: Set<String> = ["mp4", "m4v", "mov"]

    /// Video codecs that iOS can decode natively
    private static let iOSCompatibleVideoCodecs: Set<String> = ["h264", "hevc", "h265", "avc", "avc1"]

    /// Audio codecs that iOS can decode natively
    private static let iOSCompatibleAudioCodecs: Set<String> = ["aac", "ac3", "eac3", "mp3", "alac", "flac"]
    /// Build a stream info from playback info response
    public static func buildStreamInfo(
        from response: PlaybackInfoResponse,
        serverURL: URL,
        accessToken: String,
        deviceID: String
    ) -> StreamInfo? {
        guard let mediaSource = response.mediaSources.first else {
            return nil
        }

        return buildStreamInfo(
            from: mediaSource,
            playSessionId: response.playSessionId,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        )
    }

    /// Build stream info from a specific media source with smart playback selection
    /// Uses DirectPlay for iOS-compatible formats, HLS transcoding for incompatible formats
    public static func buildStreamInfo(
        from mediaSource: MediaSource,
        playSessionId: String?,
        serverURL: URL,
        accessToken: String,
        deviceID: String
    ) -> StreamInfo? {
        let headers = buildAuthHeaders(
            accessToken: accessToken,
            deviceID: deviceID
        )

        // Check iOS compatibility and log format details
        let isCompatible = logFormatInfoAndCheckCompatibility(mediaSource: mediaSource)

        // Determine stream type and URL based on compatibility
        guard let (streamURL, streamType) = determinePlaybackMethod(
            mediaSource: mediaSource,
            serverURL: serverURL,
            isCompatible: isCompatible,
            accessToken: accessToken,
            deviceID: deviceID
        ) else {
            return nil
        }

        // Build full URL with auth parameters for all stream types
        let authenticatedURL = appendAuthParameters(
            to: streamURL,
            accessToken: accessToken,
            deviceID: deviceID
        )

        return StreamInfo(
            url: authenticatedURL,
            type: streamType,
            mediaSourceId: mediaSource.id,
            playSessionId: playSessionId,
            durationSeconds: mediaSource.runtimeSeconds,
            audioStreams: mediaSource.audioStreams,
            subtitleStreams: mediaSource.subtitleStreams,
            selectedAudioIndex: mediaSource.defaultAudioStream?.index,
            selectedSubtitleIndex: mediaSource.defaultSubtitleStream?.index,
            headers: headers
        )
    }

    /// Determine the best playback method based on format compatibility
    /// Returns nil if no suitable playback method is available
    private static func determinePlaybackMethod(
        mediaSource: MediaSource,
        serverURL: URL,
        isCompatible: Bool,
        accessToken: String,
        deviceID: String
    ) -> (URL, StreamInfo.StreamType)? {
        if isCompatible, mediaSource.supportsDirectPlay == true {
            print("📹 [StreamURL] Playback Method: DirectPlay (iOS-compatible format)")
            return (buildDirectPlayURL(mediaSourceId: mediaSource.id, serverURL: serverURL), .directPlay)
        }

        if isCompatible, let directUrl = mediaSource.directStreamUrl, mediaSource.supportsDirectStream == true {
            guard let url = URL(string: directUrl, relativeTo: serverURL) else { return nil }
            print("📹 [StreamURL] Playback Method: DirectStream (iOS-compatible format)")
            return (url, .directStream)
        }

        if let transcodingUrl = mediaSource.transcodingUrl, mediaSource.supportsTranscoding == true {
            guard let url = URL(string: transcodingUrl, relativeTo: serverURL) else { return nil }
            print("📹 [StreamURL] Playback Method: HLS (transcoding required)")
            return (url, .hls)
        }

        // If format is incompatible but server supports transcoding, build HLS URL ourselves
        if !isCompatible, mediaSource.supportsTranscoding == true {
            let hlsURL = buildHLSURL(
                itemId: mediaSource.id,
                mediaSourceId: mediaSource.id,
                serverURL: serverURL,
                accessToken: accessToken,
                deviceID: deviceID
            )
            print("📹 [StreamURL] Playback Method: HLS (format incompatible, forcing transcode)")
            return (hlsURL, .hls)
        }

        if mediaSource.supportsDirectPlay == true {
            if !isCompatible {
                print("📹 [StreamURL] ⚠️ Format incompatible, no transcoding. Trying DirectPlay anyway.")
            }
            print("📹 [StreamURL] Playback Method: DirectPlay (fallback)")
            return (buildDirectPlayURL(mediaSourceId: mediaSource.id, serverURL: serverURL), .directPlay)
        }

        print("📹 [StreamURL] ❌ No suitable playback method found for media source")
        return nil
    }

    // MARK: - iOS Compatibility Check

    /// Check if a media source can be played natively on iOS without transcoding
    public static func isIOSCompatible(mediaSource: MediaSource) -> Bool {
        // Check container format
        guard let container = mediaSource.container?.lowercased(),
              iOSCompatibleContainers.contains(container)
        else {
            return false
        }

        // Check video codec
        let videoStreams = mediaSource.videoStreams
        if let primaryVideo = videoStreams.first,
           let videoCodec = primaryVideo.codec?.lowercased() {
            if !iOSCompatibleVideoCodecs.contains(videoCodec) {
                return false
            }
        }

        // Check audio codec
        let audioStreams = mediaSource.audioStreams
        if let primaryAudio = audioStreams.first,
           let audioCodec = primaryAudio.codec?.lowercased() {
            if !iOSCompatibleAudioCodecs.contains(audioCodec) {
                return false
            }
        }

        return true
    }

    /// Check if a container format is iOS-compatible
    public static func isContainerCompatible(_ container: String?) -> Bool {
        guard let container = container?.lowercased() else { return false }
        return iOSCompatibleContainers.contains(container)
    }

    /// Check if a video codec is iOS-compatible
    public static func isVideoCodecCompatible(_ codec: String?) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        return iOSCompatibleVideoCodecs.contains(codec)
    }

    /// Check if an audio codec is iOS-compatible
    public static func isAudioCodecCompatible(_ codec: String?) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        return iOSCompatibleAudioCodecs.contains(codec)
    }

    /// Build a direct play URL for a media source
    public static func buildDirectPlayURL(
        mediaSourceId: String,
        serverURL: URL
    ) -> URL {
        serverURL
            .appendingPathComponent("Videos")
            .appendingPathComponent(mediaSourceId)
            .appendingPathComponent("stream")
    }

    /// Build an HLS master playlist URL
    public static func buildHLSURL(
        itemId: String,
        mediaSourceId: String,
        serverURL: URL,
        accessToken: String,
        deviceID: String,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil
    ) -> URL {
        guard var components = URLComponents(
            url: serverURL
                .appendingPathComponent("Videos")
                .appendingPathComponent(itemId)
                .appendingPathComponent("master.m3u8"),
            resolvingAgainstBaseURL: false
        ) else {
            return serverURL
        }

        var queryItems = [
            URLQueryItem(name: "mediaSourceId", value: mediaSourceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "DeviceId", value: deviceID),
            // Transcoding parameters for iOS compatibility
            URLQueryItem(name: "videoCodec", value: "h264"),
            URLQueryItem(name: "audioCodec", value: "aac"),
            URLQueryItem(name: "segmentContainer", value: "ts"),
            URLQueryItem(name: "breakOnNonKeyFrames", value: "true")
        ]

        if let audioIndex = audioStreamIndex {
            queryItems.append(URLQueryItem(name: "AudioStreamIndex", value: String(audioIndex)))
        }

        if let subtitleIndex = subtitleStreamIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: String(subtitleIndex)))
        }

        components.queryItems = queryItems
        return components.url ?? serverURL
    }

    // MARK: - Download URL Building

    /// Download quality settings for transcoded downloads
    public struct DownloadQualitySettings: Sendable {
        public let maxWidth: Int?
        public let maxBitrate: Int?

        public init(maxWidth: Int? = nil, maxBitrate: Int? = nil) {
            self.maxWidth = maxWidth
            self.maxBitrate = maxBitrate
        }

        /// Original quality (no transcoding limits)
        public static let original = DownloadQualitySettings()

        /// High quality (1080p, ~8 Mbps)
        public static let high = DownloadQualitySettings(maxWidth: 1920, maxBitrate: 8_000_000)

        /// Medium quality (720p, ~4 Mbps)
        public static let medium = DownloadQualitySettings(maxWidth: 1280, maxBitrate: 4_000_000)

        /// Low quality (480p, ~1.5 Mbps)
        public static let low = DownloadQualitySettings(maxWidth: 854, maxBitrate: 1_500_000)
    }

    /// Build a download URL for a media source
    /// Uses direct download for compatible formats, HLS transcoding for incompatible formats
    /// - Parameters:
    ///   - mediaSource: The media source to download
    ///   - serverURL: The Jellyfin server URL
    ///   - accessToken: The access token for authentication
    ///   - deviceID: The device ID for authentication
    ///   - quality: Quality settings for transcoded downloads
    /// - Returns: Tuple of (URL, isTranscoded) or nil if no suitable method available
    public static func buildDownloadURL(
        mediaSource: MediaSource,
        serverURL: URL,
        accessToken: String,
        deviceID: String,
        quality: DownloadQualitySettings = .original
    ) -> (url: URL, isTranscoded: Bool)? {
        let isCompatible = isIOSCompatible(mediaSource: mediaSource)

        // Log for debugging
        let container = mediaSource.container ?? "unknown"
        let videoCodec = mediaSource.videoStreams.first?.codec ?? "none"
        let audioCodec = mediaSource.audioStreams.first?.codec ?? "none"
        print("📥 [Download] Format: \(container) | Video: \(videoCodec) | Audio: \(audioCodec)")
        print("📥 [Download] iOS compatible: \(isCompatible)")

        // For compatible formats with original quality, use direct download
        if isCompatible, quality.maxWidth == nil {
            let url = buildDirectDownloadURL(
                itemId: mediaSource.id,
                mediaSourceId: mediaSource.id,
                serverURL: serverURL,
                accessToken: accessToken
            )
            print("📥 [Download] Method: Direct Download (iOS-compatible, original quality)")
            return (url, false)
        }

        // For compatible formats with quality restrictions, still need to transcode
        if isCompatible, quality.maxWidth != nil {
            let url = buildTranscodedDownloadURL(
                itemId: mediaSource.id,
                mediaSourceId: mediaSource.id,
                serverURL: serverURL,
                accessToken: accessToken,
                deviceID: deviceID,
                quality: quality
            )
            print("📥 [Download] Method: Transcoded Download (quality restricted)")
            return (url, true)
        }

        // For incompatible formats, must transcode
        if mediaSource.supportsTranscoding == true {
            let url = buildTranscodedDownloadURL(
                itemId: mediaSource.id,
                mediaSourceId: mediaSource.id,
                serverURL: serverURL,
                accessToken: accessToken,
                deviceID: deviceID,
                quality: quality
            )
            print("📥 [Download] Method: Transcoded Download (format incompatible)")
            return (url, true)
        }

        // Fallback: try direct download anyway (may fail on playback)
        if mediaSource.supportsDirectPlay == true {
            let url = buildDirectDownloadURL(
                itemId: mediaSource.id,
                mediaSourceId: mediaSource.id,
                serverURL: serverURL,
                accessToken: accessToken
            )
            print("📥 [Download] Method: Direct Download (fallback, may be incompatible)")
            return (url, false)
        }

        print("📥 [Download] ❌ No suitable download method available")
        return nil
    }

    /// Build a direct download URL (original file)
    private static func buildDirectDownloadURL(
        itemId: String,
        mediaSourceId: String,
        serverURL: URL,
        accessToken: String
    ) -> URL {
        guard var components = URLComponents(
            url: serverURL
                .appendingPathComponent("Items")
                .appendingPathComponent(itemId)
                .appendingPathComponent("Download"),
            resolvingAgainstBaseURL: false
        ) else {
            return serverURL
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "mediaSourceId", value: mediaSourceId)
        ]

        return components.url ?? serverURL
    }

    // Build a transcoded download URL (HLS for iOS compatibility)
    // swiftlint:disable:next function_parameter_count
    private static func buildTranscodedDownloadURL(
        itemId: String,
        mediaSourceId: String,
        serverURL: URL,
        accessToken: String,
        deviceID: String,
        quality: DownloadQualitySettings
    ) -> URL {
        guard var components = URLComponents(
            url: serverURL
                .appendingPathComponent("Videos")
                .appendingPathComponent(itemId)
                .appendingPathComponent("master.m3u8"),
            resolvingAgainstBaseURL: false
        ) else {
            return serverURL
        }

        var queryItems = [
            URLQueryItem(name: "mediaSourceId", value: mediaSourceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "DeviceId", value: deviceID),
            // Transcode to iOS-compatible formats
            URLQueryItem(name: "videoCodec", value: "h264"),
            URLQueryItem(name: "audioCodec", value: "aac"),
            URLQueryItem(name: "segmentContainer", value: "ts"),
            URLQueryItem(name: "breakOnNonKeyFrames", value: "true"),
            // Use static mode for download (not adaptive streaming)
            URLQueryItem(name: "static", value: "false")
        ]

        // Add quality restrictions
        if let maxWidth = quality.maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if let maxBitrate = quality.maxBitrate {
            queryItems.append(URLQueryItem(name: "videoBitRate", value: String(maxBitrate)))
        }

        components.queryItems = queryItems
        return components.url ?? serverURL
    }

    /// Build authorization headers
    public static func buildAuthHeaders(
        accessToken: String,
        deviceID: String,
        clientName: String = "Seer",
        clientVersion: String = "1.0.0"
    ) -> [String: String] {
        let authValue = """
        MediaBrowser Client="\(clientName)", \
        Device="iOS", \
        DeviceId="\(deviceID)", \
        Version="\(clientVersion)", \
        Token="\(accessToken)"
        """

        return [
            "Authorization": authValue,
            "Accept": "application/json"
        ]
    }

    /// Append auth parameters to URL for HLS streams
    private static func appendAuthParameters(
        to url: URL,
        accessToken: String,
        deviceID: String
    ) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }

        var queryItems = components.queryItems ?? []

        // Only add if not already present
        if !queryItems.contains(where: { $0.name == "api_key" }) {
            queryItems.append(URLQueryItem(name: "api_key", value: accessToken))
        }

        if !queryItems.contains(where: { $0.name == "DeviceId" }) {
            queryItems.append(URLQueryItem(name: "DeviceId", value: deviceID))
        }

        components.queryItems = queryItems
        return components.url ?? url
    }

    /// Log format information and check iOS compatibility
    /// Returns true if the media source is iOS-compatible
    private static func logFormatInfoAndCheckCompatibility(mediaSource: MediaSource) -> Bool {
        let container = mediaSource.container ?? "unknown"
        let videoStreams = mediaSource.videoStreams
        let audioStreams = mediaSource.audioStreams
        let videoCodec = videoStreams.first?.codec ?? "none"
        let audioCodec = audioStreams.first?.codec ?? "none"
        let videoResolution = videoStreams.first.map { "\($0.width ?? 0)x\($0.height ?? 0)" } ?? "unknown"

        print("📹 [StreamURL] Format: \(container) | Video: \(videoCodec) \(videoResolution) | Audio: \(audioCodec)")

        let isCompatible = isIOSCompatible(mediaSource: mediaSource)
        let containerOK = isContainerCompatible(container)
        let videoOK = isVideoCodecCompatible(videoCodec)
        let audioOK = isAudioCodecCompatible(audioCodec)

        print("📹 [StreamURL] iOS: \(isCompatible) (C:\(containerOK) V:\(videoOK) A:\(audioOK))")
        let canDirectPlay = mediaSource.supportsDirectPlay ?? false
        let canDirectStream = mediaSource.supportsDirectStream ?? false
        let canTranscode = mediaSource.supportsTranscoding ?? false
        print("📹 [StreamURL] Server: DP=\(canDirectPlay) DS=\(canDirectStream) TC=\(canTranscode)")

        return isCompatible
    }
}
