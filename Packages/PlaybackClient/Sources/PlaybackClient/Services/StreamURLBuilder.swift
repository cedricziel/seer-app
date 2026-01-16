import Foundation

/// Builds authenticated stream URLs for Jellyfin media
public enum StreamURLBuilder {
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

    /// Build stream info from a specific media source
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

        // Determine stream type and URL
        let (url, streamType): (URL?, StreamInfo.StreamType)

        if let directUrl = mediaSource.directStreamUrl, mediaSource.supportsDirectStream == true {
            // Direct stream URL from server
            url = URL(string: directUrl, relativeTo: serverURL)
            streamType = .directStream
        } else if let transcodingUrl = mediaSource.transcodingUrl, mediaSource.supportsTranscoding == true {
            // HLS transcoding URL
            url = URL(string: transcodingUrl, relativeTo: serverURL)
            streamType = .hls
        } else if mediaSource.supportsDirectPlay == true {
            // Build direct play URL manually
            url = buildDirectPlayURL(
                mediaSourceId: mediaSource.id,
                serverURL: serverURL
            )
            streamType = .directPlay
        } else {
            return nil
        }

        guard let streamURL = url else {
            return nil
        }

        // Build full URL with auth parameters for HLS
        let authenticatedURL: URL
        if streamType == .hls {
            authenticatedURL = appendAuthParameters(
                to: streamURL,
                accessToken: accessToken,
                deviceID: deviceID
            )
        } else {
            authenticatedURL = streamURL
        }

        let defaultAudio = mediaSource.defaultAudioStream
        let defaultSubtitle = mediaSource.defaultSubtitleStream

        return StreamInfo(
            url: authenticatedURL,
            type: streamType,
            mediaSourceId: mediaSource.id,
            playSessionId: playSessionId,
            durationSeconds: mediaSource.runtimeSeconds,
            audioStreams: mediaSource.audioStreams,
            subtitleStreams: mediaSource.subtitleStreams,
            selectedAudioIndex: defaultAudio?.index,
            selectedSubtitleIndex: defaultSubtitle?.index,
            headers: headers
        )
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
        serverURL: URL,
        accessToken: String,
        deviceID: String,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil
    ) -> URL {
        var components = URLComponents(
            url: serverURL
                .appendingPathComponent("Videos")
                .appendingPathComponent(itemId)
                .appendingPathComponent("master.m3u8"),
            resolvingAgainstBaseURL: false
        )!

        var queryItems = [
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "DeviceId", value: deviceID)
        ]

        if let audioIndex = audioStreamIndex {
            queryItems.append(URLQueryItem(name: "AudioStreamIndex", value: String(audioIndex)))
        }

        if let subtitleIndex = subtitleStreamIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: String(subtitleIndex)))
        }

        components.queryItems = queryItems
        return components.url!
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
}
