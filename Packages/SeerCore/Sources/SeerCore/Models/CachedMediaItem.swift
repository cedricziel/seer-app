import Foundation
import SwiftData

/// Cached media item for offline browsing
/// Stores essential metadata for browsing without network
@Model
public final class CachedMediaItem {
    // Note: CloudKit doesn't support unique constraints
    public var id: String = ""
    public var serverConfigurationID: UUID = UUID()

    // MARK: - Core Fields

    public var name: String = ""
    public var overview: String?
    public var year: Int?
    public var communityRating: Double?
    public var officialRating: String?
    public var runTimeTicks: Int64?
    public var mediaType: String = ""

    // MARK: - Hierarchy (series/seasons/episodes)

    public var seriesId: String?
    public var seriesName: String?
    public var seasonName: String?
    public var indexNumber: Int?
    public var parentIndexNumber: Int?

    // MARK: - User Progress (syncs bidirectionally)

    public var playbackPositionTicks: Int64?
    public var playCount: Int?
    public var isFavorite: Bool = false
    public var isPlayed: Bool = false
    public var lastPlayedDate: Date?

    // MARK: - Image Data

    public var imageBlurHashPrimary: String?
    public var imageBlurHashBackdrop: String?
    public var hasLocalPrimaryImage: Bool = false

    // MARK: - Metadata

    public var lastSyncedAt: Date = Date()
    public var premiereDate: Date?

    // MARK: - Format Information

    public var container: String?
    public var videoCodec: String?
    public var audioCodec: String?
    public var videoResolution: String?
    public var audioChannels: Int?

    // MARK: - Relationship IDs (for predicate queries)

    public var libraryId: String?
    public var parentSeriesStoredId: String?
    public var parentSeasonStoredId: String?

    // MARK: - Relationships

    public var library: CachedLibrary?

    @Relationship(deleteRule: .cascade, inverse: \CachedMediaItem.parentSeries)
    public var seasons: [CachedMediaItem]?

    @Relationship(deleteRule: .cascade, inverse: \CachedMediaItem.parentSeason)
    public var episodes: [CachedMediaItem]?

    public var parentSeries: CachedMediaItem?
    public var parentSeason: CachedMediaItem?

    public init(
        id: String,
        serverConfigurationID: UUID,
        name: String,
        overview: String? = nil,
        year: Int? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        runTimeTicks: Int64? = nil,
        mediaType: String,
        seriesId: String? = nil,
        seriesName: String? = nil,
        seasonName: String? = nil,
        indexNumber: Int? = nil,
        parentIndexNumber: Int? = nil,
        playbackPositionTicks: Int64? = nil,
        playCount: Int? = nil,
        isFavorite: Bool = false,
        isPlayed: Bool = false,
        lastPlayedDate: Date? = nil,
        imageBlurHashPrimary: String? = nil,
        imageBlurHashBackdrop: String? = nil,
        hasLocalPrimaryImage: Bool = false,
        lastSyncedAt: Date = Date(),
        premiereDate: Date? = nil,
        container: String? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoResolution: String? = nil,
        audioChannels: Int? = nil,
        libraryId: String? = nil,
        library: CachedLibrary? = nil,
        parentSeries: CachedMediaItem? = nil,
        parentSeason: CachedMediaItem? = nil
    ) {
        self.id = id
        self.serverConfigurationID = serverConfigurationID
        self.name = name
        self.overview = overview
        self.year = year
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.runTimeTicks = runTimeTicks
        self.mediaType = mediaType
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.seasonName = seasonName
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.playbackPositionTicks = playbackPositionTicks
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.isPlayed = isPlayed
        self.lastPlayedDate = lastPlayedDate
        self.imageBlurHashPrimary = imageBlurHashPrimary
        self.imageBlurHashBackdrop = imageBlurHashBackdrop
        self.hasLocalPrimaryImage = hasLocalPrimaryImage
        self.lastSyncedAt = lastSyncedAt
        self.premiereDate = premiereDate
        self.container = container
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.videoResolution = videoResolution
        self.audioChannels = audioChannels
        self.libraryId = libraryId ?? library?.id
        self.library = library
        self.parentSeries = parentSeries
        self.parentSeason = parentSeason
        parentSeriesStoredId = parentSeries?.id
        parentSeasonStoredId = parentSeason?.id
    }

    // MARK: - Computed Properties

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
