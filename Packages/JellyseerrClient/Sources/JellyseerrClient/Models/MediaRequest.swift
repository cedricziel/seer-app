import Foundation

/// Represents a media request in Jellyseerr
public struct MediaRequest: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let status: RequestStatus
    public let createdAt: String
    public let updatedAt: String
    public let type: RequestType
    public let is4k: Bool
    public let serverId: Int?
    public let profileId: Int?
    public let rootFolder: String?
    public let languageProfileId: Int?
    public let tags: [Int]?
    public let media: MediaDetails
    public let requestedBy: User
    public let modifiedBy: User?
    public let seasons: [SeasonRequest]?

    public enum RequestStatus: Int, Codable, Sendable {
        case pending = 1
        case approved = 2
        case declined = 3
        case available = 4
        case processing = 5

        public var displayName: String {
            switch self {
            case .pending: "Pending"
            case .approved: "Approved"
            case .declined: "Declined"
            case .available: "Available"
            case .processing: "Processing"
            }
        }

        public var iconName: String {
            switch self {
            case .pending: "clock"
            case .approved: "checkmark.circle"
            case .declined: "xmark.circle"
            case .available: "checkmark.seal.fill"
            case .processing: "arrow.triangle.2.circlepath"
            }
        }
    }

    public enum RequestType: String, Codable, Sendable {
        case movie
        case tvShow = "tv"
    }

    public struct MediaDetails: Codable, Sendable, Hashable {
        public let id: Int
        public let tmdbId: Int?
        public let tvdbId: Int?
        public let status: Int?
        public let mediaType: String?
        public let externalServiceId: Int?
        public let externalServiceSlug: String?
        // Additional fields for media info (may be populated)
        public let title: String?
        public let name: String?
        public let originalTitle: String?
        public let posterPath: String?

        public var displayMediaType: String {
            switch mediaType {
            case "movie": "Movie"
            case "tv": "TV Show"
            default: mediaType ?? "Unknown"
            }
        }

        /// Returns the display title (title for movies, name for TV)
        public var displayTitle: String? {
            title ?? name ?? originalTitle
        }
    }

    public struct User: Codable, Sendable, Hashable {
        public let id: Int
        public let email: String?
        public let username: String?
        public let plexToken: String?
        public let plexUsername: String?
        public let jellyfinUsername: String?
        public let avatar: String?
        public let permissions: Int?
        public let userType: Int?
        public let createdAt: String?
        public let updatedAt: String?
        public let requestCount: Int?

        public var displayName: String {
            jellyfinUsername ?? plexUsername ?? username ?? email ?? "Unknown User"
        }
    }

    public struct SeasonRequest: Codable, Sendable, Hashable {
        public let id: Int
        public let seasonNumber: Int
        public let status: Int
    }

    /// Formatted creation date
    public var formattedCreatedAt: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return createdAt
    }
}

/// Response wrapper for requests endpoint
public struct RequestsResponse: Codable, Sendable {
    public let pageInfo: PageInfo
    public let results: [MediaRequest]

    public struct PageInfo: Codable, Sendable {
        public let pages: Int
        public let pageSize: Int
        public let results: Int
        public let page: Int
    }
}

/// Request body for creating a new request
public struct CreateRequestBody: Codable, Sendable {
    public let mediaType: String
    public let mediaId: Int
    public let tvdbId: Int?
    public let seasons: [Int]?
    public let is4k: Bool

    public init(mediaType: String, mediaId: Int, tvdbId: Int? = nil, seasons: [Int]? = nil, is4k: Bool = false) {
        self.mediaType = mediaType
        self.mediaId = mediaId
        self.tvdbId = tvdbId
        self.seasons = seasons
        self.is4k = is4k
    }
}
