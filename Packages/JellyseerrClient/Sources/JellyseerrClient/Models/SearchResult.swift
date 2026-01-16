import Foundation

/// Represents a search result from Jellyseerr/TMDB
public struct SearchResult: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let mediaType: MediaType
    public let title: String?
    public let name: String?
    public let originalTitle: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?
    public let genreIds: [Int]?
    public let mediaInfo: MediaInfo?

    public enum MediaType: String, Codable, Sendable {
        case movie
        case tv
        case person
    }

    public struct MediaInfo: Codable, Sendable, Hashable {
        public let id: Int?
        public let tmdbId: Int?
        public let tvdbId: Int?
        public let status: MediaStatus?
        public let requests: [MediaRequest]?

        public enum MediaStatus: Int, Codable, Sendable {
            case unknown = 1
            case pending = 2
            case processing = 3
            case partiallyAvailable = 4
            case available = 5
        }

        public struct MediaRequest: Codable, Sendable, Hashable {
            public let id: Int
            public let status: Int
        }
    }

    /// Display title (handles both movies and TV shows)
    public var displayTitle: String {
        title ?? name ?? originalTitle ?? originalName ?? "Unknown"
    }

    /// Display year from release date or first air date
    public var displayYear: String? {
        let dateString = releaseDate ?? firstAirDate
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }

    /// Full poster URL
    public func posterURL(size: String = "w500") -> URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(posterPath)")
    }

    /// Full backdrop URL
    public func backdropURL(size: String = "w1280") -> URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(backdropPath)")
    }

    /// Whether this media is already available
    public var isAvailable: Bool {
        mediaInfo?.status == .available
    }

    /// Whether this media has a pending request
    public var hasPendingRequest: Bool {
        guard let status = mediaInfo?.status else { return false }
        return status == .pending || status == .processing
    }
}

/// Response wrapper for search endpoint
public struct SearchResponse: Codable, Sendable {
    public let page: Int
    public let totalPages: Int
    public let totalResults: Int
    public let results: [SearchResult]
}
