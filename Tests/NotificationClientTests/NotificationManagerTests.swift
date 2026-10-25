@testable import NotificationClient
import SwiftData
import UserNotifications
import XCTest

@MainActor
final class NotificationManagerTests: XCTestCase {
    func testPermissionCheckUpdatesCacheAfterAuthorizationInSettings() async throws {
        let center = InMemoryNotificationCenter(status: .denied)
        let manager = try makeManager(center: center)
        await manager.refresh()
        center.status = .authorized

        let granted = await manager.requestPermissionIfNeeded()

        XCTAssertTrue(granted)
        XCTAssertTrue(manager.isAuthorized)
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    func testPermissionCheckClearsCacheAfterRevocationInSettings() async throws {
        let center = InMemoryNotificationCenter(status: .authorized)
        let manager = try makeManager(center: center)
        await manager.refresh()
        center.status = .denied

        let granted = await manager.requestPermissionIfNeeded()

        XCTAssertFalse(granted)
        XCTAssertFalse(manager.isAuthorized)
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    func testSchedulingUsesAuthorizationGrantedInSettings() async throws {
        let center = InMemoryNotificationCenter(status: .denied)
        let manager = try makeManager(center: center)
        await manager.refresh()
        center.status = .authorized

        try await manager.scheduleNotification(
            title: "Ready", body: "Download complete", category: .downloadCompleted, identifier: "download-1"
        )

        XCTAssertTrue(manager.isAuthorized)
        XCTAssertEqual(center.pendingRequests.map(\.identifier), ["download-1"])
        XCTAssertEqual(center.pendingRequests.first?.content.title, "Ready")
    }

    func testSchedulingStopsAfterAuthorizationRevokedInSettings() async throws {
        let center = InMemoryNotificationCenter(status: .authorized)
        let manager = try makeManager(center: center)
        await manager.refresh()
        center.status = .denied

        try await manager.scheduleNotification(
            title: "Ready", body: "Download complete", category: .downloadCompleted, identifier: "download-1"
        )

        XCTAssertFalse(manager.isAuthorized)
        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testFirstPermissionRequestUpdatesAuthorizationCache() async throws {
        let center = InMemoryNotificationCenter(status: .notDetermined)
        let manager = try makeManager(center: center)

        let granted = await manager.requestPermissionIfNeeded()

        XCTAssertTrue(granted)
        XCTAssertTrue(manager.isAuthorized)
        XCTAssertEqual(center.authorizationRequests, 1)
    }

    func testProvisionalAuthorizationAllowsSchedulingWithoutPrompt() async throws {
        let center = InMemoryNotificationCenter(status: .provisional)
        let manager = try makeManager(center: center)

        let granted = await manager.requestPermissionIfNeeded()
        try await manager.scheduleNotification(
            title: "Ready", body: "Download complete", category: .downloadCompleted, identifier: "download-1"
        )

        XCTAssertTrue(granted)
        XCTAssertTrue(manager.isAuthorized)
        XCTAssertEqual(center.pendingRequests.map(\.identifier), ["download-1"])
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    private func makeManager(center: InMemoryNotificationCenter) throws -> NotificationManager {
        let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return NotificationManager(modelContainer: container, notificationCenter: center)
    }
}

@MainActor
final class InMemoryNotificationCenter: NotificationCenterClient {
    var onAuthorizationCheck: (() -> Void)?
    var status: UNAuthorizationStatus
    private(set) var authorizationRequests = 0
    private(set) var pendingRequests: [UNNotificationRequest] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        onAuthorizationCheck?()
        return status
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        status = .authorized
        return true
    }

    func setup(delegate _: any UNUserNotificationCenterDelegate) {}

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllDeliveredNotifications() {}
}
