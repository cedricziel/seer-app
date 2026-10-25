import Foundation
import JellyseerrClient
@testable import NotificationClient
import SwiftData
import XCTest

final class RequestStatusPollerTests: XCTestCase {
    func testApprovalAndDeclineUseRequestStatus() async throws {
        let approved = try await run([response(status: 1), response(status: 2)])
        XCTAssertEqual(approved.events, ["A:Request Approved"])
        let declined = try await run([response(status: 1), response(status: 3)])
        XCTAssertEqual(declined.events, ["A:Request Declined"])
    }

    func testApprovedRequestBecomesAvailableWhenMediaFinishes() async throws {
        let result = try await run([
            response(media: 3), response(media: 5), response(media: 5)
        ])
        XCTAssertEqual(result.events, ["A:Media Available"])
        XCTAssertEqual(result.cached?.status, 2)
        XCTAssertEqual(result.cached?.mediaStatus, 5)
    }

    func testPartialAvailabilityWaitsForFullAvailability() async throws {
        let partial = try await run([response(media: 3), response(media: 4)])
        XCTAssertTrue(partial.events.isEmpty)
        let available = try await run([response(media: 4), response(media: 5)])
        XCTAssertEqual(available.events, ["A:Media Available"])
    }

    func test4KRequestUses4KAvailability() async throws {
        let result = try await run([
            response(media: 5, media4k: 3, is4k: true),
            response(media: 5, media4k: 4, is4k: true),
            response(media: 5, media4k: 5, is4k: true),
            response(media: 5, media4k: 5, is4k: true)
        ])
        XCTAssertEqual(result.events, ["A:Media Available"])
        XCTAssertEqual(result.cached?.mediaStatus, 5)
    }

    func test4KRequestWithMissingAvailabilityDoesNotUseStandardStatus() async throws {
        let result = try await run([
            response(media: 3, media4k: nil, is4k: true),
            response(media: 5, media4k: nil, is4k: true)
        ])
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertNil(result.cached?.mediaStatus)
    }

    func testAvailabilityChangeIsScopedToItsServer() async throws {
        let result = try await run([response(media: 3), response(media: 5)], otherServer: true)
        XCTAssertEqual(result.events, ["A:Media Available"])
        XCTAssertEqual(result.other?.status, 1)
        XCTAssertEqual(result.other?.mediaStatus, 3)
    }

    func testStandardRequestIgnores4KAvailability() async throws {
        let result = try await run([
            response(media: 3, media4k: 3), response(media: 3, media4k: 5)
        ])
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.cached?.mediaStatus, 3)
    }

    func testFirstPollAndUnchangedPollDoNotNotify() async throws {
        let result = try await run([response(media: 5), response(media: 5)])
        XCTAssertTrue(result.events.isEmpty)
    }

    func testLegacyCacheEstablishesBaselineWithoutRetrospectiveNotification() async throws {
        let result = try await run([response(media: 5), response(media: 5)], legacyStatus: 2)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.cached?.status, 2)
        XCTAssertEqual(result.cached?.mediaStatus, 5)
    }

    func testLegacyInvalidRequestStatusIsReplaced() async throws {
        let result = try await run([response(media: 3)], legacyStatus: 4)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.cached?.status, 2)
        XCTAssertEqual(result.cached?.mediaStatus, 3)
    }

    func testLegacyPendingCacheStillNotifiesApproval() async throws {
        let result = try await run([response(status: 2)], legacyStatus: 1)
        XCTAssertEqual(result.events, ["A:Request Approved"])
    }

    func testSameRequestIDOnAnotherServerDoesNotAffectBaseline() async throws {
        let result = try await run([response(media: 5)], otherServer: true)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.other?.status, 1)
        XCTAssertEqual(result.other?.mediaStatus, 3)
        XCTAssertEqual(result.cached?.mediaStatus, 5)
    }

    func testDeclinedRequestDoesNotAnnounceAvailableMedia() async throws {
        let result = try await run([
            response(status: 3, media: 3), response(status: 3, media: 5)
        ])
        XCTAssertTrue(result.events.isEmpty)
    }

    private struct Result {
        let events: [String]
        let cached: CachedRequestStatusSnapshot?
        let other: CachedRequestStatusSnapshot?
    }

    private func run(
        _ responses: [RequestsResponse],
        legacyStatus: Int? = nil,
        otherServer: Bool = false
    ) async throws -> Result {
        let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = NotificationStore(modelContainer: container)
        if let legacyStatus {
            try await store.upsertCachedStatus(
                requestID: 7, status: legacyStatus, mediaTitle: "Title", mediaType: "movie", serverID: "A"
            )
        }
        if otherServer {
            try await store.upsertCachedStatus(
                requestID: 7, status: 1, mediaTitle: "Other", mediaType: "movie", serverID: "B", mediaStatus: 3
            )
        }
        let source = Responses(responses)
        let notifications = Notifications()
        let poller = RequestStatusPoller(
            modelContainer: container,
            serverID: "A",
            fetchRequests: { await source.next() },
            notify: { changes, serverID in await notifications.record(changes, serverID: serverID) }
        )
        for _ in responses {
            await poller.poll()
        }
        return try await Result(
            events: notifications.events,
            cached: store.fetchCachedStatus(requestID: 7, serverID: "A"),
            other: store.fetchCachedStatus(requestID: 7, serverID: "B")
        )
    }

    private func response(
        status: Int = 2,
        media: Int = 3,
        media4k: Int? = 1,
        is4k: Bool = false
    ) throws -> RequestsResponse {
        var mediaDetails: [String: Any] = ["id": 42, "status": media, "title": "Title"]
        if let media4k {
            mediaDetails["status4k"] = media4k
        }
        let json: [String: Any] = [
            "pageInfo": ["pages": 1, "pageSize": 50, "results": 1, "page": 1],
            "results": [[
                "id": 7, "status": status, "createdAt": "2026-01-01", "updatedAt": "2026-01-01",
                "type": "movie", "is4k": is4k,
                "media": mediaDetails,
                "requestedBy": ["id": 1]
            ]]
        ]
        return try JSONDecoder().decode(RequestsResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

private actor Responses {
    private var values: [RequestsResponse]

    init(_ values: [RequestsResponse]) {
        self.values = values
    }

    func next() -> RequestsResponse {
        values.removeFirst()
    }
}

private actor Notifications {
    private(set) var events: [String] = []

    func record(_ changes: [RequestStatusChange], serverID: String) {
        events += changes.map { "\(serverID):\($0.notificationTitle)" }
    }
}
