import JellyseerrClient
@testable import NotificationClient
import SwiftData
import XCTest

final class RequestPollingRetirementTests: XCTestCase {
    func testRetiredPollerRejectsBackgroundPollAndRestart() async throws {
        let container = try makeContainer()
        let calls = PollCalls()
        let poller = RequestStatusPoller(
            modelContainer: container, serverID: "A",
            fetchRequests: { try await calls.fetch() }, notify: { _, _ in }
        )
        await poller.retire()
        try await poller.configure(serverURL: XCTUnwrap(URL(string: "https://unused.invalid")), apiKey: "test-key")
        await poller.startPolling()
        await poller.poll()

        let count = await calls.count
        await poller.stopPolling()
        XCTAssertEqual(count, 0)
    }

    func testRetirementDuringFetchPreventsCachingOrNotifications() async throws {
        let container = try makeContainer()
        let source = SuspendedPoll()
        let poller = RequestStatusPoller(
            modelContainer: container, serverID: "A",
            fetchRequests: { await source.fetch() }, notify: { _, _ in await source.notify() }
        )
        let task = Task { await poller.poll() }
        await source.waitForFetch()
        await poller.retire()
        try await source.finish(response())
        await task.value

        let cached = try await NotificationStore(modelContainer: container).fetchAllCachedStatuses(forServerID: "A")
        let notifications = await source.notifications
        XCTAssertTrue(cached.isEmpty)
        XCTAssertEqual(notifications, 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
        return try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private func response() throws -> RequestsResponse {
        let json = """
        {"pageInfo":{"pages":1,"pageSize":50,"results":1,"page":1},"results":[
        {"id":7,"status":2,"createdAt":"2026-01-01","updatedAt":"2026-01-01","type":"movie",
        "is4k":false,"media":{"id":42,"status":5,"title":"Title"},"requestedBy":{"id":1}}]}
        """
        return try JSONDecoder().decode(RequestsResponse.self, from: Data(json.utf8))
    }
}

private actor PollCalls {
    private(set) var count = 0

    func fetch() throws -> RequestsResponse {
        count += 1
        let json = """
        {"pageInfo":{"pages":0,"pageSize":50,"results":0,"page":1},"results":[]}
        """
        return try JSONDecoder().decode(RequestsResponse.self, from: Data(json.utf8))
    }
}

private actor SuspendedPoll {
    private var continuation: CheckedContinuation<RequestsResponse, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var notifications = 0

    func fetch() async -> RequestsResponse {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitForFetch() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(_ response: RequestsResponse) {
        continuation?.resume(returning: response)
        continuation = nil
    }

    func notify() {
        notifications += 1
    }
}
