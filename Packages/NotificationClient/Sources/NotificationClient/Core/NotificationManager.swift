import SwiftData
import UserNotifications

/// Main orchestrator for notification operations
@MainActor
@Observable
public final class NotificationManager: NSObject {
    // MARK: - State

    /// Whether notifications are currently authorized
    public private(set) var isAuthorized: Bool = false

    /// User's notification preferences
    public private(set) var preferences: NotificationPreferences?

    // MARK: - Dependencies

    private let store: NotificationStore
    private let notificationCenter: UNUserNotificationCenter

    // MARK: - Delegates

    /// Delegate for handling notification actions
    public weak var actionDelegate: NotificationActionDelegate?

    // MARK: - Initialization

    public init(modelContainer: ModelContainer) {
        store = NotificationStore(modelContainer: modelContainer)
        notificationCenter = UNUserNotificationCenter.current()
        super.init()

        // Load initial state
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    // MARK: - Setup

    /// Register notification categories and set delegate
    public func setup() {
        notificationCenter.setNotificationCategories(NotificationCategory.allCategories)
        notificationCenter.delegate = self
    }

    /// Refresh state from store and notification center
    public func refresh() async {
        isAuthorized = await NotificationPermissions.isAuthorized()
        preferences = try? await store.fetchPreferences()
    }

    // MARK: - Permission

    /// Request notification permission if not already requested
    /// - Parameter context: Optional context to show user why we need permission
    /// - Returns: Whether permission was granted
    @discardableResult
    public func requestPermissionIfNeeded(context _: String? = nil) async -> Bool {
        // Check if already authorized
        if await NotificationPermissions.isAuthorized() {
            return true
        }

        // Check if already asked
        if await NotificationPermissions.hasBeenRequested() {
            return false
        }

        // Request permission
        do {
            let granted = try await NotificationPermissions.requestAuthorization()
            await refresh()
            return granted
        } catch {
            print("[NotificationManager] Failed to request permission: \(error)")
            return false
        }
    }

    // MARK: - Preferences

    /// Update notification preferences
    public func updatePreferences(_ update: (inout NotificationPreferences) -> Void) async throws {
        var prefs = preferences ?? NotificationPreferences()
        update(&prefs)
        try await store.savePreferences(prefs)
        await refresh()
    }

    // MARK: - Scheduling

    /// Schedule a notification
    public func scheduleNotification(
        title: String,
        body: String,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        identifier: String = UUID().uuidString
    ) async throws {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try await notificationCenter.add(request)
    }

    /// Remove pending notifications
    public func removePendingNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Remove all delivered notifications
    public func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound, .badge]
    }

    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        // Extract values before crossing actor boundary (Swift 6 concurrency safety)
        let downloadIDString = userInfo[NotificationUserInfoKey.downloadID.rawValue] as? String
        let requestID = userInfo[NotificationUserInfoKey.requestID.rawValue] as? Int
        let mediaTitle = userInfo[NotificationUserInfoKey.mediaTitle.rawValue] as? String
        let serverID = userInfo[NotificationUserInfoKey.serverID.rawValue] as? String

        // Create a sendable info struct
        let info = NotificationInfo(
            downloadID: downloadIDString.flatMap { UUID(uuidString: $0) },
            requestID: requestID,
            mediaTitle: mediaTitle,
            serverID: serverID
        )

        await MainActor.run { [weak self] in
            guard let self, let delegate = self.actionDelegate else { return }

            // Parse category
            guard let category = NotificationCategory(rawValue: categoryID) else { return }

            // Handle based on action
            switch actionID {
            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification
                delegate.didTapNotification(category: category, info: info)

            case NotificationAction.view.rawValue:
                delegate.didTapNotification(category: category, info: info)

            case NotificationAction.retry.rawValue:
                if let downloadID = info.downloadID {
                    delegate.didTapRetryDownload(downloadID: downloadID)
                }

            case NotificationAction.cancel.rawValue:
                if let downloadID = info.downloadID {
                    delegate.didTapCancelDownload(downloadID: downloadID)
                }

            default:
                break
            }
        }
    }
}

// MARK: - NotificationInfo

/// Sendable struct containing notification payload data
public struct NotificationInfo: Sendable {
    public let downloadID: UUID?
    public let requestID: Int?
    public let mediaTitle: String?
    public let serverID: String?

    public init(
        downloadID: UUID? = nil,
        requestID: Int? = nil,
        mediaTitle: String? = nil,
        serverID: String? = nil
    ) {
        self.downloadID = downloadID
        self.requestID = requestID
        self.mediaTitle = mediaTitle
        self.serverID = serverID
    }
}

// MARK: - NotificationActionDelegate

/// Protocol for handling notification actions
public protocol NotificationActionDelegate: AnyObject, Sendable {
    /// Called when user taps a notification or the view action
    @MainActor func didTapNotification(category: NotificationCategory, info: NotificationInfo)

    /// Called when user taps the retry action on a failed download notification
    @MainActor func didTapRetryDownload(downloadID: UUID)

    /// Called when user taps the cancel action on a failed download notification
    @MainActor func didTapCancelDownload(downloadID: UUID)
}
