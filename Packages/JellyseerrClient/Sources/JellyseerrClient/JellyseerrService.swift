import Foundation
import JellyseerrAPI
import OpenAPIRuntime
import OpenAPIURLSession
import SeerCore

/// Service for interacting with the Jellyseerr API
public actor JellyseerrService {
    private var serverURL: URL
    private var apiKey: String?

    private var generatedClient: Client?

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
        case unauthorized
        case forbidden

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
            case .unauthorized:
                "Unauthorized"
            case .forbidden:
                "Forbidden - insufficient permissions"
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

        // Initialize generated client if we have an API key
        if let apiKey {
            let apiURL = serverURL.appendingPathComponent("api/v1")
            generatedClient = Client(
                serverURL: apiURL,
                transport: URLSessionTransport(),
                middlewares: [APIKeyMiddleware(apiKey: apiKey)]
            )
        }
    }

    // MARK: - Configuration

    /// Set the API key
    public func setAPIKey(_ apiKey: String) {
        self.apiKey = apiKey
        initializeGeneratedClient(serverURL: serverURL, apiKey: apiKey)
    }

    private func initializeGeneratedClient(serverURL: URL, apiKey: String) {
        let apiURL = serverURL.appendingPathComponent("api/v1")
        generatedClient = Client(
            serverURL: apiURL,
            transport: URLSessionTransport(),
            middlewares: [APIKeyMiddleware(apiKey: apiKey)]
        )
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

        var components = try serverURL
            .appendingPathComponent("api/v1/search")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
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
        var components = try serverURL
            .appendingPathComponent("api/v1/request")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "take", value: String(take)),
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "filter", value: filter.rawValue),
            URLQueryItem(name: "sort", value: sort.rawValue)
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

    /// Cancel/delete a request by ID
    public func cancelRequest(id: Int) async throws {
        let url = serverURL.appendingPathComponent("api/v1/request/\(id)")
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    // MARK: - Admin Request Actions

    /// Approve a pending request (requires MANAGE_REQUESTS permission)
    public func approveRequest(id: Int) async throws -> MediaRequest {
        let url = serverURL.appendingPathComponent("api/v1/request/\(id)/approve")
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw JellyseerrError.unauthorized
        }
        if httpResponse.statusCode == 403 {
            throw JellyseerrError.forbidden
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(MediaRequest.self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Decline a pending request (requires MANAGE_REQUESTS permission)
    public func declineRequest(id: Int) async throws -> MediaRequest {
        let url = serverURL.appendingPathComponent("api/v1/request/\(id)/decline")
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw JellyseerrError.unauthorized
        }
        if httpResponse.statusCode == 403 {
            throw JellyseerrError.forbidden
        }

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

    public enum RequestFilter: String, Sendable, CaseIterable {
        case all
        case pending
        case approved
        case declined
        case processing
        case available
        case unavailable
    }

    public enum RequestSort: String, Sendable {
        case added
        case modified
    }

    // MARK: - Discover

    /// Get trending movies and TV shows
    public func getTrending(page: Int = 1) async throws -> DiscoverResponse {
        var components = try serverURL
            .appendingPathComponent("api/v1/discover/trending")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            let rawResponse = try decoder.decode(RawDiscoverResponse.self, from: data)
            return convertTrendingResults(rawResponse)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get upcoming movies
    public func getUpcomingMovies(page: Int = 1) async throws -> DiscoverResponse {
        var components = try serverURL
            .appendingPathComponent("api/v1/discover/movies/upcoming")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            let rawResponse = try decoder.decode(RawDiscoverResponse.self, from: data)
            return convertMovieResults(rawResponse)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get upcoming TV shows
    public func getUpcomingTV(page: Int = 1) async throws -> DiscoverResponse {
        var components = try serverURL
            .appendingPathComponent("api/v1/discover/tv/upcoming")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            let rawResponse = try decoder.decode(RawDiscoverResponse.self, from: data)
            return convertTVResults(rawResponse)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get movie genres with backdrop images
    public func getMovieGenres() async throws -> [DiscoverGenre] {
        let url = serverURL.appendingPathComponent("api/v1/discover/genreslider/movie")
        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode([DiscoverGenre].self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get TV genres with backdrop images
    public func getTVGenres() async throws -> [DiscoverGenre] {
        let url = serverURL.appendingPathComponent("api/v1/discover/genreslider/tv")
        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode([DiscoverGenre].self, from: data)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get movies by genre
    public func getMoviesByGenre(genreId: Int, page: Int = 1) async throws -> DiscoverResponse {
        var components = try serverURL
            .appendingPathComponent("api/v1/discover/movies/genre/\(genreId)")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            let rawResponse = try decoder.decode(RawDiscoverResponse.self, from: data)
            return convertMovieResults(rawResponse)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    /// Get TV shows by genre
    public func getTVByGenre(genreId: Int, page: Int = 1) async throws -> DiscoverResponse {
        var components = try serverURL
            .appendingPathComponent("api/v1/discover/tv/genre/\(genreId)")
            .urlComponents()
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        let request = try authenticatedRequest(url: url)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            let rawResponse = try decoder.decode(RawDiscoverResponse.self, from: data)
            return convertTVResults(rawResponse)
        } catch {
            throw JellyseerrError.decodingError(error)
        }
    }

    // MARK: - Discover Response Conversion

    private func convertTrendingResults(_ raw: RawDiscoverResponse) -> DiscoverResponse {
        let results = raw.results.compactMap { item -> SearchResult? in
            guard let mediaType = item.mediaType else { return nil }
            return SearchResult(
                id: item.id,
                mediaType: mediaType == "movie" ? .movie : .tvShow,
                title: item.title,
                name: item.name,
                originalTitle: item.originalTitle,
                originalName: item.originalName,
                overview: item.overview,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                voteAverage: item.voteAverage,
                voteCount: item.voteCount,
                popularity: item.popularity,
                originalLanguage: item.originalLanguage,
                genreIds: item.genreIds,
                mediaInfo: item.mediaInfo
            )
        }
        return DiscoverResponse(
            page: raw.page,
            totalPages: raw.totalPages,
            totalResults: raw.totalResults,
            results: results
        )
    }

    private func convertMovieResults(_ raw: RawDiscoverResponse) -> DiscoverResponse {
        let results = raw.results.map { item in
            SearchResult(
                id: item.id,
                mediaType: .movie,
                title: item.title,
                name: item.name,
                originalTitle: item.originalTitle,
                originalName: item.originalName,
                overview: item.overview,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                voteAverage: item.voteAverage,
                voteCount: item.voteCount,
                popularity: item.popularity,
                originalLanguage: item.originalLanguage,
                genreIds: item.genreIds,
                mediaInfo: item.mediaInfo
            )
        }
        return DiscoverResponse(
            page: raw.page,
            totalPages: raw.totalPages,
            totalResults: raw.totalResults,
            results: results
        )
    }

    private func convertTVResults(_ raw: RawDiscoverResponse) -> DiscoverResponse {
        let results = raw.results.map { item in
            SearchResult(
                id: item.id,
                mediaType: .tvShow,
                title: item.title,
                name: item.name,
                originalTitle: item.originalTitle,
                originalName: item.originalName,
                overview: item.overview,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                voteAverage: item.voteAverage,
                voteCount: item.voteCount,
                popularity: item.popularity,
                originalLanguage: item.originalLanguage,
                genreIds: item.genreIds,
                mediaInfo: item.mediaInfo
            )
        }
        return DiscoverResponse(
            page: raw.page,
            totalPages: raw.totalPages,
            totalResults: raw.totalResults,
            results: results
        )
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

// MARK: - Discover Models

/// Response from discover endpoints
public struct DiscoverResponse: Codable, Sendable {
    public let page: Int
    public let totalPages: Int
    public let totalResults: Int
    public let results: [SearchResult]

    public init(page: Int, totalPages: Int, totalResults: Int, results: [SearchResult]) {
        self.page = page
        self.totalPages = totalPages
        self.totalResults = totalResults
        self.results = results
    }
}

/// Genre with backdrop images from genre slider endpoints
public struct DiscoverGenre: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let name: String
    public let backdrops: [String]?

    public init(id: Int, name: String, backdrops: [String]? = nil) {
        self.id = id
        self.name = name
        self.backdrops = backdrops
    }

    /// Get backdrop URL for the genre (uses first available backdrop)
    public func backdropURL(size: String = "w780") -> URL? {
        guard let path = backdrops?.first else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}

/// Raw response from discover endpoints before type conversion
struct RawDiscoverResponse: Codable, Sendable {
    let page: Int
    let totalPages: Int
    let totalResults: Int
    let results: [RawDiscoverResult]
}

/// Raw result item before type conversion
struct RawDiscoverResult: Codable, Sendable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let genreIds: [Int]?
    let mediaInfo: SearchResult.MediaInfo?
}
