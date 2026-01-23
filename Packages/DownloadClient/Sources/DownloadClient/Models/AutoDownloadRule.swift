import Foundation
import SwiftData

/// Configuration for automatic downloading of new episodes
@Model
public final class AutoDownloadRule {
    // MARK: - Identifiers

    /// Unique identifier for this rule
    @Attribute(.unique)
    public var id: UUID

    /// Server identifier
    public var serverID: String

    /// Series ID (nil means all series)
    public var seriesID: String?

    /// Series name for display purposes
    public var seriesName: String?

    // MARK: - Download Settings

    /// Number of unwatched episodes to keep downloaded
    public var episodesToKeep: Int

    /// Quality setting for auto-downloads
    public var qualityRawValue: String

    /// Only download on WiFi
    public var wifiOnly: Bool

    /// Maximum storage to use (in bytes, 0 = unlimited)
    public var maxStorageBytes: Int64

    // MARK: - Cleanup Settings

    /// Automatically delete watched episodes
    public var deleteWhenWatched: Bool

    /// Days to keep watched episodes before deletion
    public var daysToKeepWatched: Int

    // MARK: - State

    /// Whether this rule is active
    public var isEnabled: Bool

    /// Last time this rule was processed
    public var lastProcessedDate: Date?

    // MARK: - Timestamps

    /// When the rule was created
    public var createdDate: Date

    // MARK: - Computed Properties

    public var quality: DownloadQuality {
        get { DownloadQuality(rawValue: qualityRawValue) ?? .high }
        set { qualityRawValue = newValue.rawValue }
    }

    /// Display name for the rule
    public var displayName: String {
        seriesName ?? "All Series"
    }

    /// Maximum storage formatted
    public var formattedMaxStorage: String {
        if maxStorageBytes == 0 {
            return "Unlimited"
        }
        return ByteCountFormatter.string(fromByteCount: maxStorageBytes, countStyle: .file)
    }

    // MARK: - Initialization

    public init(
        serverID: String,
        seriesID: String? = nil,
        seriesName: String? = nil,
        episodesToKeep: Int = 3,
        quality: DownloadQuality = .high,
        wifiOnly: Bool = true,
        maxStorageBytes: Int64 = 0,
        deleteWhenWatched: Bool = true,
        daysToKeepWatched: Int = 7
    ) {
        id = UUID()
        self.serverID = serverID
        self.seriesID = seriesID
        self.seriesName = seriesName
        self.episodesToKeep = episodesToKeep
        qualityRawValue = quality.rawValue
        self.wifiOnly = wifiOnly
        self.maxStorageBytes = maxStorageBytes
        self.deleteWhenWatched = deleteWhenWatched
        self.daysToKeepWatched = daysToKeepWatched
        isEnabled = true
        createdDate = Date()
    }
}

// MARK: - Sendable Conformance

// SwiftData @Model classes need explicit Sendable conformance for cross-actor use
extension AutoDownloadRule: @unchecked Sendable {}
