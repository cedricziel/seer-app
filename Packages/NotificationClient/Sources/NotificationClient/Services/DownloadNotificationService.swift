import DownloadClient
import Foundation

/// Service that handles sending notifications for download events
@MainActor
public final class DownloadNotificationService {
    private let notificationManager: NotificationManager

    public init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
    }

    // MARK: - Download Completed

    /// Send notification for completed download
    public func notifyDownloadCompleted(
        downloadID: UUID,
        title: String,
        serverID: String,
        isAutoDownload: Bool = false
    ) async {
        // Check preferences (nil means use defaults - enabled)
        let prefs = notificationManager.preferences

        if isAutoDownload, prefs?.autoDownloadEnabled == false {
            return
        }

        if !isAutoDownload, prefs?.downloadCompletionEnabled == false {
            return
        }

        // Request permission if needed (contextual)
        let hasPermission = await notificationManager.requestPermissionIfNeeded()
        guard hasPermission else { return }

        // Schedule notification
        let prefix = isAutoDownload ? "Auto-download: " : ""
        do {
            try await notificationManager.scheduleNotification(
                title: "\(prefix)Download Complete",
                body: "\"\(title)\" is ready to watch offline.",
                category: .downloadCompleted,
                userInfo: [
                    NotificationUserInfoKey.downloadID.rawValue: downloadID.uuidString,
                    NotificationUserInfoKey.mediaTitle.rawValue: title,
                    NotificationUserInfoKey.serverID.rawValue: serverID
                ],
                identifier: "download-complete-\(downloadID.uuidString)"
            )
        } catch {
            print("[DownloadNotificationService] Failed to schedule completion notification: \(error)")
        }
    }

    // MARK: - Download Failed

    /// Send notification for failed download
    public func notifyDownloadFailed(
        downloadID: UUID,
        title: String,
        errorMessage: String,
        serverID: String
    ) async {
        // Check preferences (nil means use defaults - enabled)
        if notificationManager.preferences?.downloadFailureEnabled == false {
            return
        }

        // Request permission if needed
        let hasPermission = await notificationManager.requestPermissionIfNeeded()
        guard hasPermission else { return }

        // Schedule notification
        do {
            try await notificationManager.scheduleNotification(
                title: "Download Failed",
                body: "\"\(title)\" failed to download: \(errorMessage)",
                category: .downloadFailed,
                userInfo: [
                    NotificationUserInfoKey.downloadID.rawValue: downloadID.uuidString,
                    NotificationUserInfoKey.mediaTitle.rawValue: title,
                    NotificationUserInfoKey.serverID.rawValue: serverID
                ],
                identifier: "download-failed-\(downloadID.uuidString)"
            )
        } catch {
            print("[DownloadNotificationService] Failed to schedule failure notification: \(error)")
        }
    }
}

// MARK: - DownloadNotificationDelegate Conformance

extension DownloadNotificationService: DownloadNotificationDelegate {
    public func downloadDidComplete(
        downloadID: UUID,
        title: String,
        serverID: String,
        isAutoDownload: Bool
    ) async {
        await notifyDownloadCompleted(
            downloadID: downloadID,
            title: title,
            serverID: serverID,
            isAutoDownload: isAutoDownload
        )
    }

    public func downloadDidFail(
        downloadID: UUID,
        title: String,
        errorMessage: String,
        serverID: String
    ) async {
        await notifyDownloadFailed(
            downloadID: downloadID,
            title: title,
            errorMessage: errorMessage,
            serverID: serverID
        )
    }
}
