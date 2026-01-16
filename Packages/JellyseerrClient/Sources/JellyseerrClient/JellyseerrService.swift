import Foundation
import SeerCore

/// Service for interacting with the Jellyseerr API
public actor JellyseerrService {
    private var serverURL: URL
    private var apiKey: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public enum JellyseerrError: LocalizedError, Sendable {
        case invalidURL
        case notAuthenticated
        case invalidAPIKey
        case networkError(Error)
        case decodingError(Error)
        case serverError(Int, String?)
        case requestFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                "Invalid server URL"
            case .notAuthenticated:
                "Not authenticated"
            case .invalidAPIKey:
                "Invalid API key"
            case let .networkError(error):
                "Network error: \(error.localizedDescription)"
            case let .decodingError(error):
                "Failed to parse response: \(error.localizedDescription)"
            case let .serverError(code, message):
                "Server error (\(code)): \(message ?? "Unknown error")"
            case let .requestFailed(message):
                "Request failed: \(message)"
            }
        }
    }

    public init(serverURL: URL, apiKey: String? = nil) {
        self.serverURL = serverURL
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Configuration

    /// Set the API key
    public func setAPIKey(_ apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Authentication

    /// Verify the API key by fetching user info
    public func verifyAuth() async throws -> UserInfo {
        let url = serverURL.appendingPathComponent("api/v1/auth/me")
        let request = try authenticatedRequest(url: url)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw JellyseerrError.invalidAPIKey
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(UserInfo.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    // MARK: - Search

    /// Search for movies and TV shows
    public func search(query: String, page: Int = 1) async throws -> SearchResponse {
        guard !query.isEmpty else {
            return SearchResponse(page: 1, totalPages: 0, totalResults: 0, results: [])
        }

        var components = URLComponents(url: serverURL.appendingPathComponent("api/v1/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(SearchResponse.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    // MARK: - Requests

    /// Get all requests
    public func getRequests(
        take: Int = 20,
        skip: Int = 0,
        filter: RequestFilter = .all,
        sort: RequestSort = .added
    ) async throws -> RequestsResponse {
        var components = URLComponents(url: serverURL.appendingPathComponent("api/v1/request"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "take", value: String(take)),
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "filter", value: filter.rawValue),
            URLQueryItem(name: "sort", value: sort.rawValue),
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(RequestsResponse.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Create a new media request
    public func createRequest(
        mediaType: SearchResult.MediaType,
        mediaId: Int,
        tvdbId: Int? = nil,
        seasons: [Int]? = nil,
        is4k: Bool = false
    ) async throws -> MediaRequest {
        let url = serverURL.appendingPathComponent("api/v1/request")
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateRequestBody(
            mediaType: mediaType.rawValue,
            mediaId: mediaId,
            tvdbId: tvdbId,
            seasons: seasons,
            is4k: is4k
        )
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 409 {
            throw JellyseerrError.requestFailed("This media has already been requested")
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(MediaRequest.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get a specific request by ID
    public func getRequest(id: Int) async throws -> MediaRequest {
        let url = serverURL.appendingPathComponent("api/v1/request/\(id)")
        let request = try authenticatedRequest(url: url)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(MediaRequest.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    // MARK: - Media Details

    /// Get movie details by TMDB ID
    public func getMovieDetails(tmdbId: Int) async throws -> MovieDetails {
        let url = serverURL.appendingPathComponent("api/v1/movie/\(tmdbId)")
        let request = try authenticatedRequest(url: url)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(MovieDetails.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get TV show details by TMDB ID
    public func getTVDetails(tmdbId: Int) async throws -> TVDetails {
        let url = serverURL.appendingPathComponent("api/v1/tv/\(tmdbId)")
        let request = try authenticatedRequest(url: url)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(TVDetails.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    // MARK: - Enums

    public enum RequestFilter: String, Sendable {
        case all
        case pending
        case approved
        case processing
        case available
        case unavailable
    }

    public enum RequestSort: String, Sendable {
        case added
        case modified
    }

    // MARK: - Private Helpers

    private func authenticatedRequest(url: URL) throws -> URLRequest {
        guard let apiKey else {
            throw JellyseerrError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw JellyseerrError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.networkError(URLError(.badServerResponse))
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw JellyseerrError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
    }

    // MARK: - Public Accessors

    public func getServerURL() -> URL {
        serverURL
    }

    public func getAPIKey() -> String? {
        apiKey
    }
}

// MARK: - Additional Models

public struct MovieDetails: Codable, Sendable {
    public let id: Int
    public let title: String
    public let originalTitle: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let runtime: Int?
    public let voteAverage: Double?
    public let genres: [Genre]?
    public let mediaInfo: SearchResult.MediaInfo?

    public struct Genre: Codable, Sendable {
        public let id: Int
        public let name: String
    }

    public var displayYear: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }
}

public struct TVDetails: Codable, Sendable {
    public let id: Int
    public let name: String
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let firstAirDate: String?
    public let lastAirDate: String?
    public let numberOfSeasons: Int?
    public let numberOfEpisodes: Int?
    public let voteAverage: Double?
    public let genres: [MovieDetails.Genre]?
    public let seasons: [Season]?
    public let mediaInfo: SearchResult.MediaInfo?

    public struct Season: Codable, Sendable {
        public let id: Int
        public let seasonNumber: Int
        public let name: String?
        public let episodeCount: Int?
        public let airDate: String?
        public let posterPath: String?
    }

    public var displayYear: String? {
        guard let firstAirDate, firstAirDate.count >= 4 else { return nil }
        return String(firstAirDate.prefix(4))
    }
}
