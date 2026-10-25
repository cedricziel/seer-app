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
    public private(set) var preferences: NotificationPreferenceValues?

    // MARK: - Dependencies

    private let store: NotificationStore
    private let notificationCenter: any NotificationCenterClient

    // MARK: - Delegates

    /// Delegate for handling notification actions
    public weak var actionDelegate: NotificationActionDelegate?

    // MARK: - Initialization

    public convenience init(modelContainer: ModelContainer) {
        self.init(modelContainer: modelContainer, notificationCenter: SystemNotificationCenter())

        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    init(modelContainer: ModelContainer, notificationCenter: any NotificationCenterClient) {
        store = NotificationStore(modelContainer: modelContainer)
        self.notificationCenter = notificationCenter
        super.init()
    }

    // MARK: - Setup

    /// Register notification categories and set delegate
    public func setup() {
        #if !os(tvOS)
            notificationCenter.setup(delegate: self)
        #endif
    }

    /// Refresh state from store and notification center
    public func refresh() async {
        await refreshAuthorization()
        preferences = try? await store.fetchPreferences()
    }

    // MARK: - Permission

    /// Request notification permission if not already requested
    /// - Parameter context: Optional context to show user why we need permission
    /// - Parameter canRequestAuthorization: Rechecked after lookup before showing a permission prompt.
    /// - Returns: Whether permission was granted
    @discardableResult
    public func requestPermissionIfNeeded(
        context _: String? = nil,
        canRequestAuthorization: @MainActor () -> Bool = { true }
    ) async -> Bool {
        let status = await refreshAuthorization()
        guard status == .notDetermined else { return isAuthorized }
        guard canRequestAuthorization() else { return false }

        // Request permission
        do {
            let granted = try await notificationCenter.requestAuthorization()
            await refresh()
            return granted
        } catch {
            await refreshAuthorization()
            print("[NotificationManager] Failed to request permission: \(error)")
            return false
        }
    }

    @discardableResult
    private func refreshAuthorization() async -> UNAuthorizationStatus {
        let status = await notificationCenter.authorizationStatus()
        isAuthorized = status == .authorized || status == .provisional
        return status
    }

    // MARK: - Preferences

    /// Update notification preferences
    public func updatePreferences(_ update: (inout NotificationPreferenceValues) -> Void) async throws {
        var prefs = try await store.fetchPreferences()
        update(&prefs)
        try await store.savePreferences(prefs)
        preferences = prefs
    }

    // MARK: - Scheduling

    /// Schedule a notification
    /// - Parameter canDeliver: Rechecked after authorization lookup to suppress retired sessions.
    public func scheduleNotification(
        title: String,
        body: String,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        identifier: String = UUID().uuidString,
        canDeliver: @MainActor () -> Bool = { true }
    ) async throws {
        #if !os(tvOS)
            await refreshAuthorization()
            guard isAuthorized, canDeliver() else { return }

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
        #endif
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

#if !os(tvOS)
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

        await handleAction(actionID, categoryID: categoryID, info: info)
    }

    @MainActor
    func handleAction(_ actionID: String, categoryID: String, info: NotificationInfo) {
        guard let delegate = actionDelegate,
              let category = NotificationCategory(rawValue: categoryID)
        else { return }
        switch actionID {
        case UNNotificationDefaultActionIdentifier, NotificationAction.view.rawValue:
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

#endif

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
