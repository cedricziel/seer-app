import Foundation

/// Service that handles sending notifications for request status changes
@MainActor
public final class RequestNotificationService {
    private let notificationManager: NotificationManager
    private var isActive = true
    private let isSessionActive: @MainActor () -> Bool

    private var canNotify: Bool {
        isActive && isSessionActive()
    }

    /// Creates a service that rechecks live session state at each delivery boundary.
    public init(
        notificationManager: NotificationManager,
        isSessionActive: @escaping @MainActor () -> Bool = { true }
    ) {
        self.notificationManager = notificationManager
        self.isSessionActive = isSessionActive
    }

    /// Prevents an old session from notifying after logout or a server switch.
    public func retire() {
        isActive = false
    }

    // MARK: - Request Status Changed

    /// Send notification for request status change
    public func notifyRequestStatusChanged(_ change: RequestStatusChange, serverID: String) async {
        guard canNotify else { return }
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
        let hasPermission = await notificationManager.requestPermissionIfNeeded(
            canRequestAuthorization: { [weak self] in self?.canNotify == true }
        )
        guard hasPermission, canNotify else { return }

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
                identifier: "request-status-\(serverID)-\(change.requestID)",
                canDeliver: { [weak self] in self?.canNotify == true }
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
