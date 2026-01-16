import Foundation

/// Represents a media item from Jellyfin (movie, series, episode, etc.)
public struct MediaItem: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let originalTitle: String?
    public let overview: String?
    public let year: Int?
    public let communityRating: Double?
    public let officialRating: String?
    public let runTimeTicks: Int64?
    public let type: MediaType
    public let seriesName: String?
    public let seriesId: String?
    public let seasonName: String?
    public let indexNumber: Int?
    public let parentIndexNumber: Int?
    public let premiereDate: Date?
    public let endDate: Date?
    public let isFolder: Bool?
    public let playedPercentage: Double?
    public let userData: UserData?
    public let imageBlurHashes: ImageBlurHashes?
    public let backdropImageTags: [String]?
    public let genres: [String]?
    public let studios: [Studio]?
    public let people: [Person]?
    public let providerIds: [String: String]?

    public init(
        id: String,
        name: String,
        originalTitle: String? = nil,
        overview: String? = nil,
        year: Int? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        runTimeTicks: Int64? = nil,
        type: MediaType,
        seriesName: String? = nil,
        seriesId: String? = nil,
        seasonName: String? = nil,
        indexNumber: Int? = nil,
        parentIndexNumber: Int? = nil,
        premiereDate: Date? = nil,
        endDate: Date? = nil,
        isFolder: Bool? = nil,
        playedPercentage: Double? = nil,
        userData: UserData? = nil,
        imageBlurHashes: ImageBlurHashes? = nil,
        backdropImageTags: [String]? = nil,
        genres: [String]? = nil,
        studios: [Studio]? = nil,
        people: [Person]? = nil,
        providerIds: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.originalTitle = originalTitle
        self.overview = overview
        self.year = year
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.runTimeTicks = runTimeTicks
        self.type = type
        self.seriesName = seriesName
        self.seriesId = seriesId
        self.seasonName = seasonName
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.premiereDate = premiereDate
        self.endDate = endDate
        self.isFolder = isFolder
        self.playedPercentage = playedPercentage
        self.userData = userData
        self.imageBlurHashes = imageBlurHashes
        self.backdropImageTags = backdropImageTags
        self.genres = genres
        self.studios = studios
        self.people = people
        self.providerIds = providerIds
    }

    public enum MediaType: String, Codable, Sendable {
        case movie = "Movie"
        case series = "Series"
        case season = "Season"
        case episode = "Episode"
        case boxSet = "BoxSet"
        case musicAlbum = "MusicAlbum"
        case musicArtist = "MusicArtist"
        case audio = "Audio"
        case unknown = "Unknown"

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = MediaType(rawValue: rawValue) ?? .unknown
        }
    }

    public struct UserData: Codable, Sendable, Hashable {
        public let playbackPositionTicks: Int64?
        public let playCount: Int?
        public let isFavorite: Bool?
        public let played: Bool?
        public let lastPlayedDate: Date?

        enum CodingKeys: String, CodingKey {
            case playbackPositionTicks = "PlaybackPositionTicks"
            case playCount = "PlayCount"
            case isFavorite = "IsFavorite"
            case played = "Played"
            case lastPlayedDate = "LastPlayedDate"
        }
    }

    public struct ImageBlurHashes: Codable, Sendable, Hashable {
        public let primary: [String: String]?
        public let backdrop: [String: String]?
        public let thumb: [String: String]?

        enum CodingKeys: String, CodingKey {
            case primary = "Primary"
            case backdrop = "Backdrop"
            case thumb = "Thumb"
        }
    }

    public struct Studio: Codable, Sendable, Hashable {
        public let name: String?
        public let id: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case id = "Id"
        }
    }

    public struct Person: Codable, Sendable, Hashable {
        public let name: String?
        public let id: String?
        public let role: String?
        public let type: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case id = "Id"
            case role = "Role"
            case type = "Type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case originalTitle = "OriginalTitle"
        case overview = "Overview"
        case year = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case type = "Type"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case premiereDate = "PremiereDate"
        case endDate = "EndDate"
        case isFolder = "IsFolder"
        case playedPercentage = "PlayedPercentage"
        case userData = "UserData"
        case imageBlurHashes = "ImageBlurHashes"
        case backdropImageTags = "BackdropImageTags"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case providerIds = "ProviderIds"
    }

    /// Runtime in minutes
    public var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        return Int(ticks / 600_000_000)
    }

    /// Formatted runtime string (e.g., "2h 15m")
    public var formattedRuntime: String? {
        guard let minutes = runtimeMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    /// Whether the item can be played directly (movie or episode)
    public var isPlayable: Bool {
        type == .movie || type == .episode
    }
}

/// Response wrapper for items endpoint
public struct ItemsResponse: Codable, Sendable {
    public let items: [MediaItem]
    public let totalRecordCount: Int
    public let startIndex: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
