import Foundation
import Get
import JellyfinAPI
import SeerCore

/// Jellyfin operations exposed through app-owned media and authentication models.
public actor JellyfinService {
    private let serverURL: URL
    private var accessToken: String?
    private var userID: String?
    private let deviceID: String
    private let sessionConfiguration: URLSessionConfiguration
    private let sessionDelegate: URLSessionDelegate?
    private var transport: JellyfinSDKTransport
    private let decoder: JSONDecoder

    public enum JellyfinError: LocalizedError, Sendable {
        case invalidURL
        case notAuthenticated
        case invalidCredentials
        case networkError(Error)
        case decodingError(Error)
        case serverError(Int, String?)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                "Invalid server URL"
            case .notAuthenticated:
                "Not authenticated"
            case .invalidCredentials:
                "Invalid username or password"
            case let .networkError(error):
                "Network error: \(error.localizedDescription)"
            case let .decodingError(error):
                "Failed to parse response: \(error.localizedDescription)"
            case let .serverError(code, message):
                "Server error (\(code)): \(message ?? "Unknown error")"
            }
        }
    }

    public enum ImageType: String, Sendable {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case banner = "Banner"
    }

    public init(
        serverURL: URL,
        accessToken: String? = nil,
        userID: String? = nil,
        deviceID: String? = nil,
        session: URLSession? = nil,
        sessionConfiguration: URLSessionConfiguration? = nil
    ) {
        self.serverURL = serverURL
        self.accessToken = accessToken
        self.userID = userID
        let resolvedDeviceID = deviceID ?? Self.generateDeviceID()
        self.deviceID = resolvedDeviceID
        let sourceConfiguration = sessionConfiguration ?? session?.configuration ?? .default
        let configuration = sourceConfiguration.copy() as? URLSessionConfiguration ?? sourceConfiguration
        if session == nil {
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
        }
        self.sessionConfiguration = configuration
        sessionDelegate = session?.delegate
        transport = JellyfinSDKTransport(
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: resolvedDeviceID,
            sessionConfiguration: configuration,
            sessionDelegate: session?.delegate
        )
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle().parse(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Jellyfin date")
        }
    }

    private static func generateDeviceID() -> String {
        if let storedID = KeychainManager.shared.getString(for: .jellyfinDeviceID) {
            return storedID
        }
        let newID = UUID().uuidString
        KeychainManager.shared.save(newID, for: .jellyfinDeviceID)
        return newID
    }
}

public extension JellyfinService {
    /// Authenticates without an existing token and replaces credentials only after a successful response.
    func authenticate(username: String, password: String) async throws -> AuthResponse {
        let request = Paths.authenticateUserByName(.init(pw: password, username: username))
        let unauthenticated = JellyfinSDKTransport(
            serverURL: serverURL,
            deviceID: deviceID,
            sessionConfiguration: sessionConfiguration,
            sessionDelegate: sessionDelegate
        )
        let (data, response) = try await performRequest(request, using: unauthenticated)
        if response.statusCode == 401 {
            throw JellyfinError.invalidCredentials
        }
        try validateResponse(response, data: data)
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        setCredentials(accessToken: authResponse.accessToken, userID: authResponse.user.id)
        return authResponse
    }

    /// Restores credentials without authenticating or revoking an existing server session.
    func setCredentials(accessToken: String, userID: String) {
        self.accessToken = accessToken
        self.userID = userID
        transport = JellyfinSDKTransport(
            serverURL: serverURL,
            accessToken: accessToken,
            deviceID: deviceID,
            sessionConfiguration: sessionConfiguration,
            sessionDelegate: sessionDelegate
        )
    }

    func getLibraries() async throws -> [Library] {
        let userID = try authenticatedUserID()
        let request = Paths.getUserViews(parameters: .init(userID: userID))
        return try await decode(LibrariesResponse.self, from: request).items
    }

    func getItems(
        parentID: String? = nil,
        includeItemTypes: [MediaItem.MediaType]? = nil,
        sortBy: String = "SortName",
        sortOrder: String = "Ascending",
        limit: Int = 50,
        startIndex: Int = 0,
        recursive: Bool = true,
        filters: [String]? = nil,
        searchTerm: String? = nil
    ) async throws -> ItemsResponse {
        var parameters = try Paths.GetItemsParameters(userID: authenticatedUserID())
        parameters.parentID = parentID
        parameters.includeItemTypes = try includeItemTypes.map { try sdkValues($0.map(\.rawValue)) }
        parameters.sortBy = try sdkValues(sortBy.split(separator: ",").map(String.init))
        parameters.sortOrder = try sdkValues([sortOrder])
        parameters.limit = limit
        parameters.startIndex = startIndex
        parameters.isRecursive = recursive
        parameters.filters = try filters.map { try sdkValues($0) }
        parameters.searchTerm = searchTerm
        parameters.fields = [.overview, .genres, .studios, .people, .providerIDs]
        return try await decode(ItemsResponse.self, from: Paths.getItems(parameters: parameters))
    }

    func getItem(id: String) async throws -> MediaItem {
        try await decode(MediaItem.self, from: Paths.getItem(itemID: id, userID: authenticatedUserID()))
    }

    func getContinueWatching(limit: Int = 10) async throws -> [MediaItem] {
        let parameters = try Paths.GetResumeItemsParameters(
            userID: authenticatedUserID(),
            limit: limit,
            fields: [.overview],
            mediaTypes: [.video]
        )
        return try await decode(ItemsResponse.self, from: Paths.getResumeItems(parameters: parameters)).items
    }

    func getLatestItems(
        parentID: String? = nil,
        includeItemTypes: [MediaItem.MediaType]? = nil,
        limit: Int = 20
    ) async throws -> [MediaItem] {
        let parameters = try Paths.GetLatestMediaParameters(
            userID: authenticatedUserID(),
            parentID: parentID,
            fields: [.overview, .genres],
            includeItemTypes: includeItemTypes.map { try sdkValues($0.map(\.rawValue)) },
            limit: limit
        )
        return try await decode([MediaItem].self, from: Paths.getLatestMedia(parameters: parameters))
    }

    func getSeasons(seriesId: String) async throws -> [MediaItem] {
        try await getItems(
            parentID: seriesId,
            includeItemTypes: [.season],
            sortBy: "IndexNumber",
            limit: 100,
            recursive: false
        ).items
    }

    func getEpisodes(seasonId: String) async throws -> [MediaItem] {
        try await getItems(
            parentID: seasonId,
            includeItemTypes: [.episode],
            sortBy: "IndexNumber",
            limit: 100,
            recursive: false
        ).items
    }

    func getPerson(id: String) async throws -> PersonDetail {
        try await decode(PersonDetail.self, from: Paths.getItem(itemID: id, userID: authenticatedUserID()))
    }

    func getItems(personId: String, limit: Int = 20) async throws -> [MediaItem] {
        var parameters = try Paths.GetItemsParameters(userID: authenticatedUserID())
        parameters.personIDs = [personId]
        parameters.includeItemTypes = [.movie, .series]
        parameters.isRecursive = true
        parameters.sortBy = [.premiereDate, .sortName]
        parameters.sortOrder = [.descending]
        parameters.limit = limit
        parameters.fields = [.overview, .genres, .people]
        return try await decode(ItemsResponse.self, from: Paths.getItems(parameters: parameters)).items
    }

    func getPersonImageURL(
        personId: String,
        imageTag: String? = nil,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) -> URL {
        let request = Paths.getItemImage(
            itemID: personId,
            imageType: ImageType.primary.rawValue,
            parameters: .init(maxWidth: maxWidth, maxHeight: maxHeight, tag: imageTag)
        )
        return transport.url(for: request) ?? serverURL
    }

    func search(query: String, limit: Int = 20) async throws -> [MediaItem] {
        var parameters = try Paths.GetItemsParameters(userID: authenticatedUserID())
        parameters.searchTerm = query
        parameters.limit = limit
        parameters.isRecursive = true
        parameters.includeItemTypes = [.movie, .series]
        parameters.fields = [.overview, .genres]
        return try await decode(ItemsResponse.self, from: Paths.getItems(parameters: parameters)).items
    }

    func getImageURL(
        itemID: String,
        imageType: ImageType = .primary,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) -> URL {
        let request = Paths.getItemImage(
            itemID: itemID,
            imageType: imageType.rawValue,
            parameters: .init(maxWidth: maxWidth, maxHeight: maxHeight)
        )
        return transport.url(for: request) ?? serverURL
    }

    func getServerURL() -> URL {
        serverURL
    }

    func getAccessToken() -> String? {
        accessToken
    }

    func getUserID() -> String? {
        userID
    }

    func getDeviceID() -> String {
        deviceID
    }

    func reportPlaybackProgress(itemId: String, positionTicks: Int64, isPaused: Bool) async throws {
        _ = try authenticatedUserID()
        let body = OfflinePlaybackProgress(
            itemID: itemId,
            positionTicks: positionTicks,
            isPaused: isPaused,
            playSessionID: UUID().uuidString
        )
        var request = Paths.reportPlaybackProgress()
        request.body = body
        try await send(request)
    }

    func setFavorite(itemId: String, isFavorite: Bool) async throws {
        let userID = try authenticatedUserID()
        if isFavorite {
            try await send(Paths.markFavoriteItem(itemID: itemId, userID: userID))
        } else {
            try await send(Paths.unmarkFavoriteItem(itemID: itemId, userID: userID))
        }
    }

    func markAsPlayed(itemId: String) async throws {
        try await send(Paths.markPlayedItem(itemID: itemId, userID: authenticatedUserID()))
    }

    func markAsUnplayed(itemId: String) async throws {
        try await send(Paths.markUnplayedItem(itemID: itemId, userID: authenticatedUserID()))
    }
}

private extension JellyfinService {
    func authenticatedUserID() throws -> String {
        guard let userID, accessToken != nil else { throw JellyfinError.notAuthenticated }
        return userID
    }

    func sdkValues<T: RawRepresentable>(_ values: [String]) throws -> [T] where T.RawValue == String {
        try values.map { value in
            guard let result = T(rawValue: value) else { throw JellyfinError.invalidURL }
            return result
        }
    }

    func performRequest(
        _ request: Request<some Any>,
        using client: JellyfinSDKTransport? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await (client ?? transport).data(for: request)
        } catch {
            throw JellyfinError.networkError(error)
        }
    }

    func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200 ... 299).contains(response.statusCode) else {
            throw JellyfinError.serverError(response.statusCode, String(data: data, encoding: .utf8))
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from request: Request<some Any>) async throws -> T {
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try decoder.decode(type, from: data)
    }

    func send(_ request: Request<some Any>) async throws {
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }
}

private struct OfflinePlaybackProgress: Encodable {
    let itemID: String
    let positionTicks: Int64
    let isPaused: Bool
    let playSessionID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "ItemId"
        case positionTicks = "PositionTicks"
        case isPaused = "IsPaused"
        case playSessionID = "PlaySessionId"
    }
}
