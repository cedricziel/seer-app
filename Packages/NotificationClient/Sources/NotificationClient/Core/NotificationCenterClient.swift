import UserNotifications

@MainActor
protocol NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func setup(delegate: any UNUserNotificationCenterDelegate)
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllDeliveredNotifications()
}

#if os(tvOS)
    @MainActor
    final class SystemNotificationCenter: NotificationCenterClient {
        func authorizationStatus() async -> UNAuthorizationStatus {
            .denied
        }

        func requestAuthorization() async throws -> Bool {
            false
        }

        func setup(delegate _: any UNUserNotificationCenterDelegate) {}
        func add(_: UNNotificationRequest) async throws {}
        func removePendingNotificationRequests(withIdentifiers _: [String]) {}
        func removeAllDeliveredNotifications() {}
    }
#else
    @MainActor
    final class SystemNotificationCenter: NotificationCenterClient {
        private let center = UNUserNotificationCenter.current()

        func authorizationStatus() async -> UNAuthorizationStatus {
            await center.notificationSettings().authorizationStatus
        }

        func requestAuthorization() async throws -> Bool {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }

        func setup(delegate: any UNUserNotificationCenterDelegate) {
            center.setNotificationCategories(NotificationCategory.allCategories)
            center.delegate = delegate
        }

        func add(_ request: UNNotificationRequest) async throws {
            try await center.add(request)
        }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        func removeAllDeliveredNotifications() {
            center.removeAllDeliveredNotifications()
        }
    }

#endif
