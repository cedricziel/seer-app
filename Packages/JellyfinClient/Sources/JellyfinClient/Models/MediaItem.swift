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
    public let videoRangeType: String?
    public let audioSpatialFormat: String?
    public let fileSizeBytes: Int64?

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
        audioChannels: Int? = nil,
        videoRangeType: String? = nil,
        audioSpatialFormat: String? = nil,
        fileSizeBytes: Int64? = nil
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
        self.videoRangeType = videoRangeType
        self.audioSpatialFormat = audioSpatialFormat
        self.fileSizeBytes = fileSizeBytes
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
        case videoRangeType = "VideoRangeType"
        case audioSpatialFormat = "AudioSpatialFormat"
        case fileSizeBytes = "Size"
        case mediaSources = "MediaSources"
    }

    // MARK: - Private Types for Parsing MediaSources

    /// Format-related fields resolved during decoding, either from direct top-level keys
    /// (round-trip re-encoding) or extracted from the first `MediaSources` entry.
    private struct FormatInfo {
        var container: String?
        var videoCodec: String?
        var audioCodec: String?
        var videoResolution: String?
        var audioChannels: Int?
        var videoRangeType: String?
        var audioSpatialFormat: String?
        var fileSizeBytes: Int64?

        /// True when any field could still be filled in from `MediaSources`.
        var isMissingAnyField: Bool {
            container == nil || videoCodec == nil || audioCodec == nil || videoResolution == nil
                || audioChannels == nil || videoRangeType == nil || audioSpatialFormat == nil || fileSizeBytes == nil
        }
    }

    private struct APIMediaSource: Decodable {
        let container: String?
        let size: Int64?
        let mediaStreams: [APIMediaStream]?

        enum CodingKeys: String, CodingKey {
            case container = "Container"
            case size = "Size"
            case mediaStreams = "MediaStreams"
        }
    }

    private struct APIMediaStream: Decodable {
        let type: String?
        let codec: String?
        let width: Int?
        let height: Int?
        let channels: Int?
        let videoRangeType: String?
        let audioSpatialFormat: String?

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case codec = "Codec"
            case width = "Width"
            case height = "Height"
            case channels = "Channels"
            case videoRangeType = "VideoRangeType"
            case audioSpatialFormat = "AudioSpatialFormat"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            codec = try container.decodeIfPresent(String.self, forKey: .codec)
            width = try container.decodeIfPresent(Int.self, forKey: .width)
            height = try container.decodeIfPresent(Int.self, forKey: .height)
            channels = try container.decodeIfPresent(Int.self, forKey: .channels)
            // Enum-valued fields: tolerate a non-string wire form rather than failing the item.
            videoRangeType = (try? container.decodeIfPresent(String.self, forKey: .videoRangeType)) ?? nil
            audioSpatialFormat = (try? container.decodeIfPresent(String.self, forKey: .audioSpatialFormat)) ?? nil
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

        let formatInfo = try Self.decodeFormatInfo(from: container)
        self.container = formatInfo.container
        videoCodec = formatInfo.videoCodec
        audioCodec = formatInfo.audioCodec
        videoResolution = formatInfo.videoResolution
        audioChannels = formatInfo.audioChannels
        videoRangeType = formatInfo.videoRangeType
        audioSpatialFormat = formatInfo.audioSpatialFormat
        fileSizeBytes = formatInfo.fileSizeBytes
    }

    /// Decodes format properties directly first (for re-encoding round-trips); if container or
    /// video codec are still missing, falls back to extracting them from the first `MediaSources`
    /// entry (the shape returned by the Jellyfin API).
    private static func decodeFormatInfo(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> FormatInfo {
        var info = try FormatInfo(
            container: container.decodeIfPresent(String.self, forKey: .container),
            videoCodec: container.decodeIfPresent(String.self, forKey: .videoCodec),
            audioCodec: container.decodeIfPresent(String.self, forKey: .audioCodec),
            videoResolution: container.decodeIfPresent(String.self, forKey: .videoResolution),
            audioChannels: container.decodeIfPresent(Int.self, forKey: .audioChannels),
            videoRangeType: Self.lenientString(in: container, forKey: .videoRangeType),
            audioSpatialFormat: Self.lenientString(in: container, forKey: .audioSpatialFormat),
            fileSizeBytes: container.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
        )

        guard info.isMissingAnyField,
              let mediaSources = try container.decodeIfPresent([APIMediaSource].self, forKey: .mediaSources),
              let firstSource = mediaSources.first else { return info }

        info.container = info.container ?? firstSource.container
        info.fileSizeBytes = info.fileSizeBytes ?? firstSource.size

        if let streams = firstSource.mediaStreams {
            if let videoStream = streams.first(where: { $0.type == "Video" }) {
                info.videoCodec = info.videoCodec ?? videoStream.codec
                info.videoRangeType = info.videoRangeType ?? videoStream.videoRangeType
                if let width = videoStream.width, let height = videoStream.height {
                    info.videoResolution = info.videoResolution ?? Self.formatResolution(
                        width: width,
                        height: height
                    )
                }
            }

            if let audioStream = streams.first(where: { $0.type == "Audio" }) {
                info.audioCodec = info.audioCodec ?? audioStream.codec
                info.audioChannels = info.audioChannels ?? audioStream.channels
                info.audioSpatialFormat = info.audioSpatialFormat ?? audioStream.audioSpatialFormat
            }
        }

        return info
    }

    /// Jellyfin serialises its enums as strings, but a server or proxy that emits the numeric
    /// form must not make the whole item (and with it the whole page) fail to decode. Anything
    /// that is not a string is treated as unknown.
    private static func lenientString(
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
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
        try container.encodeIfPresent(videoRangeType, forKey: .videoRangeType)
        try container.encodeIfPresent(audioSpatialFormat, forKey: .audioSpatialFormat)
        try container.encodeIfPresent(fileSizeBytes, forKey: .fileSizeBytes)
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

    /// Formatted runtime string using long-form units (e.g., "2 hr 8 min", "8 min")
    public var formattedDurationLong: String? {
        guard let minutes = runtimeMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours) hr \(mins) min"
        }
        return "\(mins) min"
    }

    /// Remaining time text based on playback position (e.g., "1 hr 12 min left", "21 min left").
    /// Returns nil when the runtime or a nonzero playback position is unavailable.
    public var remainingTimeText: String? {
        guard let totalTicks = runTimeTicks,
              let positionTicks = userData?.playbackPositionTicks,
              positionTicks > 0 else { return nil }

        let remainingTicks = totalTicks - positionTicks
        guard remainingTicks > 0 else { return nil }

        let remainingMinutes = Int(remainingTicks / 600_000_000)
        guard remainingMinutes > 0 else { return "Less than a minute left" }
        let hours = remainingMinutes / 60
        let mins = remainingMinutes % 60
        if hours > 0 {
            return "\(hours) hr \(mins) min left"
        }
        return "\(mins) min left"
    }

    /// Whether the item can be played directly (movie or episode)
    public var isPlayable: Bool {
        type == .movie || type == .episode
    }

    /// Formatted video info string. When HDR metadata is present the codec is dropped in
    /// favor of a short resolution + HDR label (e.g., "4K · HDR10"); otherwise falls back to
    /// codec + resolution (e.g., "H.264 1080p").
    public var formattedVideoInfo: String? {
        guard let codec = videoCodec else { return nil }
        let codecDisplay = codec.uppercased()
        guard let resolution = videoResolution else { return codecDisplay }
        guard let hdr = hdrLabel else { return "\(codecDisplay) \(resolution)" }
        return "\(resolution) · \(hdr)"
    }

    /// Short HDR label derived from `videoRangeType` (e.g., "HDR10", "HDR10+", "Dolby Vision",
    /// "HLG"). Returns nil for SDR or an unknown/missing range type.
    private var hdrLabel: String? {
        guard let rangeType = videoRangeType, !rangeType.isEmpty else { return nil }
        let normalized = rangeType.lowercased()
        guard normalized != "sdr", normalized != "unknown" else { return nil }
        if normalized.contains("dovi") { return "Dolby Vision" }
        if normalized == "hdr10plus" || normalized == "hdr10+" { return "HDR10+" }
        if normalized == "hdr10" { return "HDR10" }
        if normalized == "hlg" { return "HLG" }
        return rangeType
    }

    /// Formatted audio info string. Uses a Dolby/DTS branded label when the stream's spatial
    /// format signals immersive audio (e.g., "Atmos 7.1"); otherwise falls back to the codec
    /// name and channel layout (e.g., "AAC 5.1").
    public var formattedAudioInfo: String? {
        guard let codec = audioCodec else { return nil }
        let codecDisplay = spatialAudioLabel ?? codec.uppercased()
        guard let channels = audioChannels else { return codecDisplay }
        return "\(codecDisplay) \(Self.channelLabel(for: channels))"
    }

    /// Dolby/DTS branded label for a recognized immersive audio spatial format, if any.
    private var spatialAudioLabel: String? {
        guard let format = audioSpatialFormat else { return nil }
        switch format.lowercased() {
        case "dolbyatmos", "atmos": return "Atmos"
        case "dtsx", "dts:x": return "DTS:X"
        default: return nil
        }
    }

    private static func channelLabel(for channels: Int) -> String {
        switch channels {
        case 1: "Mono"
        case 2: "Stereo"
        case 6: "5.1"
        case 8: "7.1"
        default: "\(channels)ch"
        }
    }

    /// Formatted container string, appending a human-readable file size when known
    /// (e.g., "MKV · 18 GB"); otherwise just the container (e.g., "MP4").
    public var formattedContainer: String? {
        guard let container else { return formattedFileSize }
        guard let size = formattedFileSize else { return container.uppercased() }
        return "\(container.uppercased()) · \(size)"
    }

    /// Human-readable file size (e.g., "18 GB"), or nil when unknown.
    private var formattedFileSize: String? {
        guard let bytes = fileSizeBytes, bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
