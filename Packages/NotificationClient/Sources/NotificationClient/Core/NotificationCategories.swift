import UserNotifications

/// Notification categories and actions used by the app
public enum NotificationCategory: String, CaseIterable, Sendable {
    case downloadCompleted = "DOWNLOAD_COMPLETED"
    case downloadFailed = "DOWNLOAD_FAILED"
    case requestStatusChanged = "REQUEST_STATUS_CHANGED"

    /// User-facing notification category objects
    public var category: UNNotificationCategory {
        switch self {
        case .downloadCompleted:
            UNNotificationCategory(
                identifier: rawValue,
                actions: [NotificationAction.view.action],
                intentIdentifiers: [],
                options: []
            )
        case .downloadFailed:
            UNNotificationCategory(
                identifier: rawValue,
                actions: [
                    NotificationAction.retry.action,
                    NotificationAction.cancel.action
                ],
                intentIdentifiers: [],
                options: []
            )
        case .requestStatusChanged:
            UNNotificationCategory(
                identifier: rawValue,
                actions: [NotificationAction.view.action],
                intentIdentifiers: [],
                options: []
            )
        }
    }

    /// All categories to register with the notification center
    public static var allCategories: Set<UNNotificationCategory> {
        Set(allCases.map(\.category))
    }
}

/// Notification actions that users can take
public enum NotificationAction: String, Sendable {
    case view = "VIEW_ACTION"
    case retry = "RETRY_ACTION"
    case cancel = "CANCEL_ACTION"

    var action: UNNotificationAction {
        switch self {
        case .view:
            UNNotificationAction(
                identifier: rawValue,
                title: "View",
                options: [.foreground]
            )
        case .retry:
            UNNotificationAction(
                identifier: rawValue,
                title: "Retry",
                options: []
            )
        case .cancel:
            UNNotificationAction(
                identifier: rawValue,
                title: "Cancel",
                options: [.destructive]
            )
        }
    }
}

/// Keys used in notification userInfo dictionaries
public enum NotificationUserInfoKey: String, Sendable {
    case downloadID
    case requestID
    case mediaTitle
    case serverID
}
