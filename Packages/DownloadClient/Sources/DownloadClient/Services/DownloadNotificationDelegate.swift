import Foundation

// MARK: - Notification Delegate Protocol

/// Protocol for notifying about download events (for notifications)
public protocol DownloadNotificationDelegate: AnyObject, Sendable {
    /// Called when a download completes successfully
    @MainActor func downloadDidComplete(
        downloadID: UUID,
        title: String,
        serverID: String,
        isAutoDownload: Bool
    ) async

    /// Called when a download fails
    @MainActor func downloadDidFail(
        downloadID: UUID,
        title: String,
        errorMessage: String,
        serverID: String
    ) async
}
