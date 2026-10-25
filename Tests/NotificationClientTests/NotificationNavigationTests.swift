@testable import NotificationClient
import SwiftData
import UserNotifications
import XCTest

@MainActor
final class NotificationNavigationTests: XCTestCase {
    #if !os(tvOS)
        func testDefaultActionRoutesRequestToItsServer() throws {
            let (manager, delegate) = try makeManager()
            let server = UUID()
            manager.handleAction(
                UNNotificationDefaultActionIdentifier,
                categoryID: NotificationCategory.requestStatusChanged.rawValue,
                info: NotificationInfo(requestID: 7, serverID: server.uuidString)
            )
            XCTAssertEqual(delegate.navigation.pendingDestination, .request(serverID: server, requestID: 7))
        }

        func testViewActionRoutesDownloadToItsServer() throws {
            let (manager, delegate) = try makeManager()
            let server = UUID()
            let download = UUID()
            manager.handleAction(
                NotificationAction.view.rawValue,
                categoryID: NotificationCategory.downloadCompleted.rawValue,
                info: NotificationInfo(downloadID: download, serverID: server.uuidString)
            )
            XCTAssertEqual(delegate.navigation.pendingDestination, .download(serverID: server, downloadID: download))
        }

        private func makeManager() throws -> (NotificationManager, NavigationDelegate) {
            let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            let manager = NotificationManager(
                modelContainer: container, notificationCenter: InMemoryNotificationCenter(status: .authorized)
            )
            let delegate = NavigationDelegate()
            manager.actionDelegate = delegate
            return (manager, delegate)
        }

    #endif

    func testColdLaunchRequestWaitsForAuthenticationOnItsServer() {
        let navigation = NotificationNavigation()
        let server = UUID()
        navigation.receive(
            category: .requestStatusChanged,
            info: NotificationInfo(requestID: 7, serverID: server.uuidString)
        )

        XCTAssertNil(navigation.consume { _ in false })
        XCTAssertEqual(navigation.pendingDestination, .request(serverID: server, requestID: 7))
        let destination = navigation.consume { $0 == server }
        XCTAssertEqual(destination, .request(serverID: server, requestID: 7))
        XCTAssertNil(navigation.pendingDestination)
    }

    func testLaunchSheetDefersDestinationUntilPresentationIsReady() {
        let navigation = NotificationNavigation()
        let server = UUID()
        navigation.receive(
            category: .requestStatusChanged, info: NotificationInfo(requestID: 7, serverID: server.uuidString)
        )

        XCTAssertNil(navigation.consume(if: false) { _ in true })
        XCTAssertEqual(navigation.pendingDestination, .request(serverID: server, requestID: 7))
        XCTAssertEqual(navigation.consume(if: true) { _ in true }, .request(serverID: server, requestID: 7))
        XCTAssertNil(navigation.pendingDestination)
    }

    func testDownloadRetainsServerAndDownloadIdentity() {
        let navigation = NotificationNavigation()
        let server = UUID()
        let download = UUID()
        navigation.receive(
            category: .downloadCompleted,
            info: NotificationInfo(downloadID: download, serverID: server.uuidString)
        )

        XCTAssertEqual(navigation.consume { $0 == server }, .download(serverID: server, downloadID: download))
    }

    func testUnscopedAndMalformedPayloadsDoNotNavigate() {
        let navigation = NotificationNavigation()
        navigation.receive(category: .requestStatusChanged, info: NotificationInfo(requestID: 7))
        navigation.receive(category: .downloadFailed, info: NotificationInfo(serverID: UUID().uuidString))
        navigation.receive(category: .requestStatusChanged, info: NotificationInfo(requestID: 7, serverID: "old-host"))

        XCTAssertNil(navigation.pendingDestination)
    }
}

#if !os(tvOS)
    @MainActor
    private final class NavigationDelegate: NotificationActionDelegate {
        let navigation = NotificationNavigation()

        func didTapNotification(category: NotificationCategory, info: NotificationInfo) {
            navigation.receive(category: category, info: info)
        }

        func didTapRetryDownload(downloadID _: UUID) {}
        func didTapCancelDownload(downloadID _: UUID) {}
    }
#endif
