import Foundation
import SwiftData

/// Represents a downloaded media item stored locally
@Model
public final class Download {
    // MARK: - Identifiers

    /// Unique identifier for this download
    @Attribute(.unique)
    public var id: UUID

    /// Server identifier (to support multiple servers)
    public var serverID: String

    /// Jellyfin item ID
    public var itemID: String

    /// Media source ID (specific version/quality)
    public var mediaSourceID: String

    // MARK: - Cached Metadata

    /// Display name of the item
    public var name: String

    /// Series name (for episodes)
    public var seriesName: String?

    /// Season number (for episodes)
    public var seasonNumber: Int?

    /// Episode number (for episodes)
    public var episodeNumber: Int?

    /// Media type (movie, episode, etc.)
    public var mediaType: String

    /// Runtime in ticks
    public var runTimeTicks: Int64?

    /// Year of release
    public var year: Int?

    /// Primary image URL for thumbnail display
    public var primaryImageURL: String?

    // MARK: - Download State

    /// Current download state
    public var stateRawValue: String

    /// Download progress (0.0 - 1.0)
    public var progress: Double

    /// Bytes downloaded so far
    public var bytesDownloaded: Int64

    /// Total size in bytes
    public var totalBytes: Int64

    /// Error message if download failed
    public var errorMessage: String?

    // MARK: - File Storage

    /// Relative path to the downloaded file (from Documents/Downloads)
    public var relativePath: String?

    /// Quality setting used for download
    public var qualityRawValue: String

    // MARK: - Playback State

    /// Playback position in ticks
    public var playbackPositionTicks: Int64

    /// Whether the item has been watched
    public var isWatched: Bool

    // MARK: - Background Task Tracking

    /// URLSession task identifier
    public var taskIdentifier: Int?

    /// Resume data for paused downloads
    @Attribute(.externalStorage)
    public var resumeData: Data?

    // MARK: - Timestamps

    /// When the download was added to queue
    public var addedDate: Date

    /// When the download completed
    public var completedDate: Date?

    /// When the item was last played
    public var lastPlayedDate: Date?

    // MARK: - Computed Properties

    public var state: DownloadState {
        get { DownloadState(rawValue: stateRawValue) ?? .pending }
        set { stateRawValue = newValue.rawValue }
    }

    public var quality: DownloadQuality {
        get { DownloadQuality(rawValue: qualityRawValue) ?? .high }
        set { qualityRawValue = newValue.rawValue }
    }

    /// Full file URL for playback
    public var fileURL: URL? {
        guard let relativePath, state == .completed else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("Downloads").appendingPathComponent(relativePath)
    }

    /// Formatted file size
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Formatted progress percentage
    public var formattedProgress: String {
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }

    /// Display title (includes series info for episodes)
    public var displayTitle: String {
        if let seriesName, let seasonNumber, let episodeNumber {
            return "\(seriesName) - S\(seasonNumber)E\(episodeNumber) - \(name)"
        }
        return name
    }

    // MARK: - Initialization

    public init(
        serverID: String,
        itemID: String,
        mediaSourceID: String,
        name: String,
        mediaType: String,
        quality: DownloadQuality = .high,
        seriesName: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        runTimeTicks: Int64? = nil,
        year: Int? = nil,
        primaryImageURL: String? = nil
    ) {
        id = UUID()
        self.serverID = serverID
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.name = name
        self.mediaType = mediaType
        self.seriesName = seriesName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.runTimeTicks = runTimeTicks
        self.year = year
        self.primaryImageURL = primaryImageURL
        stateRawValue = DownloadState.pending.rawValue
        progress = 0
        bytesDownloaded = 0
        totalBytes = 0
        qualityRawValue = quality.rawValue
        playbackPositionTicks = 0
        isWatched = false
        addedDate = Date()
    }
}

// MARK: - Sendable Conformance

extension Download: @unchecked Sendable {}
