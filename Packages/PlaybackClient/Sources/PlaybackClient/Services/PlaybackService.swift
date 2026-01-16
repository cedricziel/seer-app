import Foundation

/// Service for managing video playback with Jellyfin
public actor PlaybackService {
    private var serverURL: URL
    private var accessToken: String
    private var userID: String
    private var deviceID: String

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let clientName = "Seer"
    private let clientVersion = "1.0.0"

    public enum PlaybackError: LocalizedError, Sendable {
        case invalidURL
        case notAuthenticated
        case networkError(Error)
        case decodingError(Error)
        case serverError(Int, String?)
        case noPlayableSource

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                "Invalid server URL"
            case .notAuthenticated:
                "Not authenticated"
            case let .networkError(error):
                "Network error: \(error.localizedDescription)"
            case let .decodingError(error):
                "Failed to parse response: \(error.localizedDescription)"
            case let .serverError(code, message):
                "Server error (\(code)): \(message ?? "Unknown error")"
            case .noPlayableSource:
                "No playable media source found"
            }
        }
    }

    public init(
        serverURL: URL,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        self.serverURL = serverURL
        self.accessToken = accessToken
        self.userID = userID
        self.deviceID = deviceID

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
    }

    // MARK: - Public API

    /// Get playback info for an item
    public func getPlaybackInfo(itemId: String, startPositionTicks: Int64 = 0) async throws -> PlaybackInfoResponse {
        let url = serverURL
            .appendingPathComponent("Items")
            .appendingPathComponent(itemId)
            .appendingPathComponent("PlaybackInfo")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(authorizationHeader(), forHTTPHeaderField: "Authorization")

        // Build request body with device profile
        let requestBody = PlaybackInfoRequest(
            userId: userID,
            maxStreamingBitrate: 120_000_000,
            startTimeTicks: startPositionTicks,
            deviceProfile: DeviceProfileBuilder.buildAppleDeviceProfile(),
            autoOpenLiveStream: true
        )

        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        return try decoder.decode(PlaybackInfoResponse.self, from: data)
    }

    /// Get stream info ready for playback
    public func getStreamInfo(itemId: String, startPositionTicks: Int64 = 0) async throws -> StreamInfo {
        let playbackInfo = try await getPlaybackInfo(itemId: itemId, startPositionTicks: startPositionTicks)

        guard let streamInfo = StreamURLBuilder.buildStreamInfo(
            from: playbackInfo,
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID
        ) else {
            throw PlaybackError.noPlayableSource
        }

        return streamInfo
    }

    /// Report playback has started
    public func reportPlaybackStart(state: PlaybackState) async throws {
        let url = serverURL.appendingPathComponent("Sessions/Playing")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authorizationHeader(), forHTTPHeaderField: "Authorization")

        let body = PlaybackStartInfo(
            canSeek: true,
            itemId: state.itemId,
            mediaSourceId: state.mediaSourceId,
            playSessionId: state.playSessionId,
            positionTicks: state.positionTicks,
            playMethod: state.playMethod.rawValue
        )

        request.httpBody = try encoder.encode(body)

        let (_, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            // Non-critical error, just log
            return
        }
    }

    /// Report playback progress
    public func reportPlaybackProgress(state: PlaybackState) async throws {
        let url = serverURL.appendingPathComponent("Sessions/Playing/Progress")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authorizationHeader(), forHTTPHeaderField: "Authorization")

        let body = PlaybackProgressInfo(
            canSeek: true,
            itemId: state.itemId,
            mediaSourceId: state.mediaSourceId,
            playSessionId: state.playSessionId,
            positionTicks: state.positionTicks,
            isPaused: state.isPaused,
            isMuted: state.isMuted,
            volumeLevel: state.volumeLevel,
            playMethod: state.playMethod.rawValue
        )

        request.httpBody = try encoder.encode(body)

        let (_, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            // Non-critical error
            return
        }
    }

    /// Report playback has stopped
    public func reportPlaybackStopped(state: PlaybackState) async throws {
        let url = serverURL.appendingPathComponent("Sessions/Playing/Stopped")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authorizationHeader(), forHTTPHeaderField: "Authorization")

        let body = PlaybackStopInfo(
            itemId: state.itemId,
            mediaSourceId: state.mediaSourceId,
            playSessionId: state.playSessionId,
            positionTicks: state.positionTicks
        )

        request.httpBody = try encoder.encode(body)

        let (_, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            return
        }
    }

    // MARK: - Private Helpers

    private func authorizationHeader() -> String {
        """
        MediaBrowser Client="\(clientName)", \
        Device="iOS", \
        DeviceId="\(deviceID)", \
        Version="\(clientVersion)", \
        Token="\(accessToken)"
        """
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw PlaybackError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaybackError.networkError(URLError(.badServerResponse))
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw PlaybackError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - Request/Response Types

private struct PlaybackInfoRequest: Encodable {
    let userId: String
    let maxStreamingBitrate: Int
    let startTimeTicks: Int64
    let deviceProfile: DeviceProfile
    let autoOpenLiveStream: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "UserId"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case startTimeTicks = "StartTimeTicks"
        case deviceProfile = "DeviceProfile"
        case autoOpenLiveStream = "AutoOpenLiveStream"
    }
}

private struct PlaybackStartInfo: Encodable {
    let canSeek: Bool
    let itemId: String
    let mediaSourceId: String
    let playSessionId: String?
    let positionTicks: Int64
    let playMethod: String

    enum CodingKeys: String, CodingKey {
        case canSeek = "CanSeek"
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case playSessionId = "PlaySessionId"
        case positionTicks = "PositionTicks"
        case playMethod = "PlayMethod"
    }
}

private struct PlaybackProgressInfo: Encodable {
    let canSeek: Bool
    let itemId: String
    let mediaSourceId: String
    let playSessionId: String?
    let positionTicks: Int64
    let isPaused: Bool
    let isMuted: Bool
    let volumeLevel: Int
    let playMethod: String

    enum CodingKeys: String, CodingKey {
        case canSeek = "CanSeek"
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case playSessionId = "PlaySessionId"
        case positionTicks = "PositionTicks"
        case isPaused = "IsPaused"
        case isMuted = "IsMuted"
        case volumeLevel = "VolumeLevel"
        case playMethod = "PlayMethod"
    }
}

private struct PlaybackStopInfo: Encodable {
    let itemId: String
    let mediaSourceId: String
    let playSessionId: String?
    let positionTicks: Int64

    enum CodingKeys: String, CodingKey {
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case playSessionId = "PlaySessionId"
        case positionTicks = "PositionTicks"
    }
}
