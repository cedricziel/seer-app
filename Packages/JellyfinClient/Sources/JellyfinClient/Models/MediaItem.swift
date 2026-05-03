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

    // MARK: - Format Information

    public let container: String?
    public let videoCodec: String?
    public let audioCodec: String?
    public let videoResolution: String?
    public let audioChannels: Int?

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
        providerIds: [String: String]? = nil,
        container: String? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoResolution: String? = nil,
        audioChannels: Int? = nil
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
        self.container = container
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.videoResolution = videoResolution
        self.audioChannels = audioChannels
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
        public let imageTag: String?

        public init(
            name: String? = nil,
            id: String? = nil,
            role: String? = nil,
            type: String? = nil,
            imageTag: String? = nil
        ) {
            self.name = name
            self.id = id
            self.role = role
            self.type = type
            self.imageTag = imageTag
        }

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case id = "Id"
            case role = "Role"
            case type = "Type"
            case imageTag = "PrimaryImageTag"
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
        case container = "Container"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
        case videoResolution = "VideoResolution"
        case audioChannels = "AudioChannels"
        case mediaSources = "MediaSources"
    }

    // MARK: - Private Types for Parsing MediaSources

    private struct APIMediaSource: Decodable {
        let container: String?
        let mediaStreams: [APIMediaStream]?

        enum CodingKeys: String, CodingKey {
            case container = "Container"
            case mediaStreams = "MediaStreams"
        }
    }

    private struct APIMediaStream: Decodable {
        let type: String?
        let codec: String?
        let width: Int?
        let height: Int?
        let channels: Int?

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case codec = "Codec"
            case width = "Width"
            case height = "Height"
            case channels = "Channels"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode standard properties
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        communityRating = try container.decodeIfPresent(Double.self, forKey: .communityRating)
        officialRating = try container.decodeIfPresent(String.self, forKey: .officialRating)
        runTimeTicks = try container.decodeIfPresent(Int64.self, forKey: .runTimeTicks)
        type = try container.decode(MediaType.self, forKey: .type)
        seriesName = try container.decodeIfPresent(String.self, forKey: .seriesName)
        seriesId = try container.decodeIfPresent(String.self, forKey: .seriesId)
        seasonName = try container.decodeIfPresent(String.self, forKey: .seasonName)
        indexNumber = try container.decodeIfPresent(Int.self, forKey: .indexNumber)
        parentIndexNumber = try container.decodeIfPresent(Int.self, forKey: .parentIndexNumber)
        premiereDate = try container.decodeIfPresent(Date.self, forKey: .premiereDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isFolder = try container.decodeIfPresent(Bool.self, forKey: .isFolder)
        playedPercentage = try container.decodeIfPresent(Double.self, forKey: .playedPercentage)
        userData = try container.decodeIfPresent(UserData.self, forKey: .userData)
        imageBlurHashes = try container.decodeIfPresent(ImageBlurHashes.self, forKey: .imageBlurHashes)
        backdropImageTags = try container.decodeIfPresent([String].self, forKey: .backdropImageTags)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        studios = try container.decodeIfPresent([Studio].self, forKey: .studios)
        people = try container.decodeIfPresent([Person].self, forKey: .people)
        providerIds = try container.decodeIfPresent([String: String].self, forKey: .providerIds)

        // Try to decode format properties directly first (for re-encoding)
        var decodedContainer = try container.decodeIfPresent(String.self, forKey: .container)
        var decodedVideoCodec = try container.decodeIfPresent(String.self, forKey: .videoCodec)
        var decodedAudioCodec = try container.decodeIfPresent(String.self, forKey: .audioCodec)
        var decodedVideoResolution = try container.decodeIfPresent(String.self, forKey: .videoResolution)
        var decodedAudioChannels = try container.decodeIfPresent(Int.self, forKey: .audioChannels)

        // If not present, extract from MediaSources (Jellyfin API response)
        if decodedContainer == nil || decodedVideoCodec == nil {
            if let mediaSources = try container.decodeIfPresent([APIMediaSource].self, forKey: .mediaSources),
               let firstSource = mediaSources.first {
                decodedContainer = decodedContainer ?? firstSource.container

                if let streams = firstSource.mediaStreams {
                    // Extract video stream info
                    if let videoStream = streams.first(where: { $0.type == "Video" }) {
                        decodedVideoCodec = decodedVideoCodec ?? videoStream.codec
                        if let width = videoStream.width, let height = videoStream.height {
                            decodedVideoResolution = decodedVideoResolution ?? Self.formatResolution(
                                width: width,
                                height: height
                            )
                        }
                    }

                    // Extract audio stream info
                    if let audioStream = streams.first(where: { $0.type == "Audio" }) {
                        decodedAudioCodec = decodedAudioCodec ?? audioStream.codec
                        decodedAudioChannels = decodedAudioChannels ?? audioStream.channels
                    }
                }
            }
        }

        self.container = decodedContainer
        videoCodec = decodedVideoCodec
        audioCodec = decodedAudioCodec
        videoResolution = decodedVideoResolution
        audioChannels = decodedAudioChannels
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(originalTitle, forKey: .originalTitle)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(communityRating, forKey: .communityRating)
        try container.encodeIfPresent(officialRating, forKey: .officialRating)
        try container.encodeIfPresent(runTimeTicks, forKey: .runTimeTicks)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(seriesName, forKey: .seriesName)
        try container.encodeIfPresent(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(seasonName, forKey: .seasonName)
        try container.encodeIfPresent(indexNumber, forKey: .indexNumber)
        try container.encodeIfPresent(parentIndexNumber, forKey: .parentIndexNumber)
        try container.encodeIfPresent(premiereDate, forKey: .premiereDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(isFolder, forKey: .isFolder)
        try container.encodeIfPresent(playedPercentage, forKey: .playedPercentage)
        try container.encodeIfPresent(userData, forKey: .userData)
        try container.encodeIfPresent(imageBlurHashes, forKey: .imageBlurHashes)
        try container.encodeIfPresent(backdropImageTags, forKey: .backdropImageTags)
        try container.encodeIfPresent(genres, forKey: .genres)
        try container.encodeIfPresent(studios, forKey: .studios)
        try container.encodeIfPresent(people, forKey: .people)
        try container.encodeIfPresent(providerIds, forKey: .providerIds)
        try container.encodeIfPresent(self.container, forKey: .container)
        try container.encodeIfPresent(videoCodec, forKey: .videoCodec)
        try container.encodeIfPresent(audioCodec, forKey: .audioCodec)
        try container.encodeIfPresent(videoResolution, forKey: .videoResolution)
        try container.encodeIfPresent(audioChannels, forKey: .audioChannels)
        // Note: mediaSources is not encoded as it's only used for decoding from API
    }

    /// Format resolution from width/height to display string
    private static func formatResolution(width _: Int, height: Int) -> String {
        switch height {
        case 0 ..< 480: "SD"
        case 480 ..< 720: "480p"
        case 720 ..< 1080: "720p"
        case 1080 ..< 2160: "1080p"
        case 2160...: "4K"
        default: "\(height)p"
        }
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

    /// Formatted video info string (e.g., "H.264 1080p")
    public var formattedVideoInfo: String? {
        guard let codec = videoCodec else { return nil }
        let codecDisplay = codec.uppercased()
        if let resolution = videoResolution {
            return "\(codecDisplay) \(resolution)"
        }
        return codecDisplay
    }

    /// Formatted audio info string (e.g., "AAC 5.1")
    public var formattedAudioInfo: String? {
        guard let codec = audioCodec else { return nil }
        let codecDisplay = codec.uppercased()
        if let channels = audioChannels {
            let channelString = switch channels {
            case 1: "Mono"
            case 2: "Stereo"
            case 6: "5.1"
            case 8: "7.1"
            default: "\(channels)ch"
            }
            return "\(codecDisplay) \(channelString)"
        }
        return codecDisplay
    }

    /// Formatted container string (e.g., "MP4")
    public var formattedContainer: String? {
        container?.uppercased()
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
