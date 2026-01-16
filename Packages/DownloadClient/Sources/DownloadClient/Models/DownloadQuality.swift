import Foundation

/// Quality settings for downloads
public enum DownloadQuality: String, Codable, Sendable, CaseIterable {
    /// Original quality (direct download, no transcoding)
    case original

    /// High quality (1080p, ~8 Mbps)
    case high

    /// Medium quality (720p, ~4 Mbps)
    case medium

    /// Low quality (480p, ~1.5 Mbps)
    case low

    /// Human-readable description
    public var displayName: String {
        switch self {
        case .original:
            "Original"
        case .high:
            "High (1080p)"
        case .medium:
            "Medium (720p)"
        case .low:
            "Low (480p)"
        }
    }

    /// Maximum bitrate in bits per second
    public var maxBitrate: Int {
        switch self {
        case .original:
            0 // No limit
        case .high:
            8_000_000
        case .medium:
            4_000_000
        case .low:
            1_500_000
        }
    }

    /// Maximum resolution width
    public var maxWidth: Int? {
        switch self {
        case .original:
            nil
        case .high:
            1920
        case .medium:
            1280
        case .low:
            854
        }
    }

    /// Estimated size per hour in MB
    public var estimatedSizePerHourMB: Int {
        switch self {
        case .original:
            4000 // Variable, estimate high
        case .high:
            3600
        case .medium:
            1800
        case .low:
            675
        }
    }
}
