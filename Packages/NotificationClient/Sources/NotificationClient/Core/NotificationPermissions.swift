import UserNotifications

/// Handles notification permission requests
public enum NotificationPermissions {
    /// Current authorization status
    public static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Request notification permissions
    /// - Returns: Whether authorization was granted
    @discardableResult
    public static func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Check if notifications are authorized
    public static func isAuthorized() async -> Bool {
        let status = await currentStatus()
        return status == .authorized || status == .provisional
    }

    /// Check if user has been asked before
    public static func hasBeenRequested() async -> Bool {
        let status = await currentStatus()
        return status != .notDetermined
    }
}
