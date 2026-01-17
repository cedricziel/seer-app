import Foundation
import SeerCore

/// Service for interacting with the Jellyfin API
public actor JellyfinService {
    private var serverURL: URL
    private var accessToken: String?
    private var userID: String?
    private var deviceID: String

    private let session: URLSession
    private let decoder: JSONDecoder

    private let clientName = "Seer"
    private let clientVersion = "1.0.0"

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

    public init(serverURL: URL, accessToken: String? = nil, userID: String? = nil, deviceID: String? = nil) {
        self.serverURL = serverURL
        self.accessToken = accessToken
        self.userID = userID
        self.deviceID = deviceID ?? Self.generateDeviceID()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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

// MARK: - Authentication

public extension JellyfinService {
    /// Authenticate with username and password
    func authenticate(username: String, password: String) async throws -> AuthResponse {
        let url = serverURL.appendingPathComponent("Users/AuthenticateByName")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authorizationHeader(includeToken: false), forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw JellyfinError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw JellyfinError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        accessToken = authResponse.accessToken
        userID = authResponse.user.id

        return authResponse
    }

    /// Set credentials without authenticating (for restoring session)
    func setCredentials(accessToken: String, userID: String) {
        self.accessToken = accessToken
        self.userID = userID
    }
}

// MARK: - Libraries

public extension JellyfinService {
    /// Get all user libraries
    func getLibraries() async throws -> [Library] {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        let url = serverURL.appendingPathComponent("Users/\(userID)/Views")
        let request = try authenticatedRequest(url: url)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let librariesResponse = try decoder.decode(LibrariesResponse.self, from: data)
        return librariesResponse.items
    }
}

// MARK: - Items

public extension JellyfinService {
    /// Get items from a library or the entire collection
    func getItems(
        parentID: String? = nil,
        includeItemTypes: [MediaItem.MediaType]? = nil,
        sortBy: String = "SortName",
        sortOrder: String = "Ascending",
        limit: Int = 50,
        startIndex: Int = 0,
        recursive: Bool = true
    ) async throws -> ItemsResponse {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        var components = try serverURL
            .appendingPathComponent("Users/\(userID)/Items")
            .urlComponents()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: sortOrder),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Recursive", value: String(recursive)),
            URLQueryItem(
                name: "Fields",
                value: "Overview,Genres,Studios,People,ProviderIds,CommunityRating,OfficialRating"
            )
        ]

        if let parentID {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentID))
        }

        if let types = includeItemTypes {
            let typeStrings = types.map(\.rawValue)
            queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: typeStrings.joined(separator: ",")))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        return try decoder.decode(ItemsResponse.self, from: data)
    }

    /// Get a single item by ID
    func getItem(id: String) async throws -> MediaItem {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        var components = try serverURL
            .appendingPathComponent("Users/\(userID)/Items/\(id)")
            .urlComponents()

        // Include MediaSources to get format information
        components.queryItems = [
            URLQueryItem(
                name: "Fields",
                value: "Overview,Genres,Studios,People,ProviderIds,CommunityRating,OfficialRating,MediaSources"
            )
        ]

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        return try decoder.decode(MediaItem.self, from: data)
    }

    /// Get continue watching items
    func getContinueWatching(limit: Int = 10) async throws -> [MediaItem] {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        var components = try serverURL
            .appendingPathComponent("Users/\(userID)/Items/Resume")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "Overview"),
            URLQueryItem(name: "MediaTypes", value: "Video")
        ]

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let itemsResponse = try decoder.decode(ItemsResponse.self, from: data)
        return itemsResponse.items
    }

    /// Get latest added items
    func getLatestItems(
        parentID: String? = nil,
        includeItemTypes: [MediaItem.MediaType]? = nil,
        limit: Int = 20
    ) async throws -> [MediaItem] {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        var components = try serverURL
            .appendingPathComponent("Users/\(userID)/Items/Latest")
            .urlComponents()
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "Overview,Genres")
        ]

        if let parentID {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentID))
        }

        if let types = includeItemTypes {
            let typeStrings = types.map(\.rawValue)
            queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: typeStrings.joined(separator: ",")))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        return try decoder.decode([MediaItem].self, from: data)
    }

    /// Get all seasons for a series
    func getSeasons(seriesId: String) async throws -> [MediaItem] {
        let response = try await getItems(
            parentID: seriesId,
            includeItemTypes: [.season],
            sortBy: "IndexNumber",
            sortOrder: "Ascending",
            limit: 100,
            recursive: false
        )
        return response.items
    }

    /// Get all episodes for a season
    func getEpisodes(seasonId: String) async throws -> [MediaItem] {
        let response = try await getItems(
            parentID: seasonId,
            includeItemTypes: [.episode],
            sortBy: "IndexNumber",
            sortOrder: "Ascending",
            limit: 100,
            recursive: false
        )
        return response.items
    }
}

// MARK: - Search

public extension JellyfinService {
    /// Search for items
    func search(query: String, limit: Int = 20) async throws -> [MediaItem] {
        guard let userID else {
            throw JellyfinError.notAuthenticated
        }

        var components = try serverURL
            .appendingPathComponent("Users/\(userID)/Items")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "SearchTerm", value: query),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Fields", value: "Overview,Genres")
        ]

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let itemsResponse = try decoder.decode(ItemsResponse.self, from: data)
        return itemsResponse.items
    }
}

// MARK: - Images

public extension JellyfinService {
    /// Get the URL for an item's primary image
    func getImageURL(
        itemID: String,
        imageType: ImageType = .primary,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) -> URL {
        guard var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemID)/Images/\(imageType.rawValue)"),
            resolvingAgainstBaseURL: false
        ) else {
            return serverURL
        }

        var queryItems: [URLQueryItem] = []
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if let maxHeight {
            queryItems.append(URLQueryItem(name: "maxHeight", value: String(maxHeight)))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url ?? serverURL
    }
}

// MARK: - Private Helpers

extension JellyfinService {
    func authenticatedRequest(url: URL) throws -> URLRequest {
        guard accessToken != nil else {
            throw JellyfinError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(authorizationHeader(includeToken: true), forHTTPHeaderField: "Authorization")

        return request
    }

    private func authorizationHeader(includeToken: Bool) -> String {
        var params = [
            "Client=\"\(clientName)\"",
            "Device=\"iOS\"",
            "DeviceId=\"\(deviceID)\"",
            "Version=\"\(clientVersion)\""
        ]

        if includeToken, let token = accessToken {
            params.append("Token=\"\(token)\"")
        }

        return "MediaBrowser \(params.joined(separator: ", "))"
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw JellyfinError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.networkError(URLError(.badServerResponse))
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw JellyfinError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - Public Accessors

public extension JellyfinService {
    func getServerURL() -> URL { serverURL }
    func getAccessToken() -> String? { accessToken }
    func getUserID() -> String? { userID }
    func getDeviceID() -> String { deviceID }
}

// MARK: - User Progress

public extension JellyfinService {
    func reportPlaybackProgress(itemId: String, positionTicks: Int64, isPaused: Bool) async throws {
        guard userID != nil else { throw JellyfinError.notAuthenticated }
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              (components.path = "/Sessions/Playing/Progress", true).1,
              let url = components.url else { throw JellyfinError.invalidURL }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "ItemId": itemId, "PositionTicks": positionTicks, "IsPaused": isPaused, "PlaySessionId": UUID().uuidString
        ] as [String: Any])
        let (_, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw JellyfinError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
    }

    func setFavorite(itemId: String, isFavorite: Bool) async throws {
        guard let userID else { throw JellyfinError.notAuthenticated }
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              (components.path = "/Users/\(userID)/FavoriteItems/\(itemId)", true).1,
              let url = components.url else { throw JellyfinError.invalidURL }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = isFavorite ? "POST" : "DELETE"
        let (_, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw JellyfinError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
    }

    func markAsPlayed(itemId: String) async throws {
        guard let userID else { throw JellyfinError.notAuthenticated }
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              (components.path = "/Users/\(userID)/PlayedItems/\(itemId)", true).1,
              let url = components.url else { throw JellyfinError.invalidURL }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "POST"
        let (_, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw JellyfinError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
    }

    func markAsUnplayed(itemId: String) async throws {
        guard let userID else { throw JellyfinError.notAuthenticated }
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              (components.path = "/Users/\(userID)/PlayedItems/\(itemId)", true).1,
              let url = components.url else { throw JellyfinError.invalidURL }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw JellyfinError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
    }
}
