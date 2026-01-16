import Foundation

/// Represents the current state of a download
public enum DownloadState: String, Codable, Sendable {
    /// Download is queued and waiting to start
    case pending

    /// Download is actively in progress
    case downloading

    /// Download is paused (can be resumed)
    case paused

    /// Download completed successfully
    case completed

    /// Download failed (check error message)
    case failed

    /// Human-readable description
    public var displayName: String {
        switch self {
        case .pending:
            "Waiting"
        case .downloading:
            "Downloading"
        case .paused:
            "Paused"
        case .completed:
            "Downloaded"
        case .failed:
            "Failed"
        }
    }

    /// SF Symbol name for the state
    public var systemImage: String {
        switch self {
        case .pending:
            "clock"
        case .downloading:
            "arrow.down.circle"
        case .paused:
            "pause.circle"
        case .completed:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.circle"
        }
    }
}
