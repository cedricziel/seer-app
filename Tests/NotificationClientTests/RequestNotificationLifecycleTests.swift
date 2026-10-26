@testable import NotificationClient
import SwiftData
import XCTest

@MainActor
final class RequestNotificationLifecycleTests: XCTestCase {
    func testRetiredServiceDoesNotRequestPermissionOrNotify() async throws {
        let center = InMemoryNotificationCenter(status: .notDetermined)
        let service = try makeService(center: center)
        service.retire()

        await service.notifyRequestStatusChanged(.approved(requestID: 7, title: "Movie"), serverID: "A")

        XCTAssertTrue(center.pendingRequests.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    func testRetirementDuringInitialAuthorizationLookupDoesNotPrompt() async throws {
        let center = InMemoryNotificationCenter(status: .notDetermined)
        let service = try makeService(center: center)
        center.onAuthorizationCheck = { service.retire() }

        await service.notifyRequestStatusChanged(.approved(requestID: 7, title: "Movie"), serverID: "A")

        XCTAssertEqual(center.authorizationRequests, 0)
        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    #if !os(tvOS)
        func testLogoutDuringSchedulingAuthorizationCheckPreventsDelivery() async throws {
            let center = InMemoryNotificationCenter(status: .authorized)
            let service = try makeService(center: center)
            var checks = 0
            center.onAuthorizationCheck = {
                checks += 1
                if checks == 2 { service.retire() }
            }

            await service.notifyRequestStatusChanged(.approved(requestID: 7, title: "Movie"), serverID: "A")

            XCTAssertEqual(checks, 2)
            XCTAssertTrue(center.pendingRequests.isEmpty)
        }

        func testServerChangeDuringAuthorizationPreventsDeliveryBeforeRetirement() async throws {
            let center = InMemoryNotificationCenter(status: .authorized)
            var sessionActive = true
            let service = try makeService(center: center, isSessionActive: { sessionActive })
            var checks = 0
            center.onAuthorizationCheck = {
                checks += 1
                if checks == 2 { sessionActive = false }
            }

            await service.notifyRequestStatusChanged(.approved(requestID: 7, title: "Movie"), serverID: "A")

            XCTAssertEqual(checks, 2)
            XCTAssertTrue(center.pendingRequests.isEmpty)
        }

    #endif

    func testMissingAuthenticatedServerDoesNotNotify() async throws {
        let center = InMemoryNotificationCenter(status: .notDetermined)
        let service = try makeService(center: center, isSessionActive: { false })

        await service.notifyRequestStatusChanged(.approved(requestID: 7, title: "Movie"), serverID: "A")

        XCTAssertTrue(center.pendingRequests.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    private func makeService(
        center: InMemoryNotificationCenter,
        isSessionActive: @escaping @MainActor () -> Bool = { true }
    ) throws -> RequestNotificationService {
        let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = NotificationManager(modelContainer: container, notificationCenter: center)
        return RequestNotificationService(notificationManager: manager, isSessionActive: isSessionActive)
    }
}
