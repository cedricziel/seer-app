import Foundation

/// Service that handles sending notifications for request status changes
@MainActor
public final class RequestNotificationService {
    private let notificationManager: NotificationManager

    public init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
    }

    // MARK: - Request Status Changed

    /// Send notification for request status change
    public func notifyRequestStatusChanged(_ change: RequestStatusChange, serverID: String) async {
        // Check preferences (nil means use defaults - enabled)
        let prefs = notificationManager.preferences

        switch change {
        case .approved:
            if prefs?.requestApprovedEnabled == false { return }
        case .available:
            if prefs?.requestAvailableEnabled == false { return }
        case .declined:
            if prefs?.requestDeclinedEnabled == false { return }
        }

        // Request permission if needed
        let hasPermission = await notificationManager.requestPermissionIfNeeded()
        guard hasPermission else { return }

        // Schedule notification
        do {
            try await notificationManager.scheduleNotification(
                title: change.notificationTitle,
                body: change.notificationBody,
                category: .requestStatusChanged,
                userInfo: [
                    NotificationUserInfoKey.requestID.rawValue: change.requestID,
                    NotificationUserInfoKey.serverID.rawValue: serverID
                ],
                identifier: "request-status-\(change.requestID)"
            )
        } catch {
            print("[RequestNotificationService] Failed to schedule notification: \(error)")
        }
    }

    /// Send notifications for multiple status changes
    public func notifyRequestStatusChanges(_ changes: [RequestStatusChange], serverID: String) async {
        for change in changes {
            await notifyRequestStatusChanged(change, serverID: serverID)
        }
    }
}
