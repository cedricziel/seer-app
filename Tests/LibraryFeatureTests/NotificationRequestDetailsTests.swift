import JellyseerrClient
@testable import SeerApp
import SeerCore
import XCTest

@MainActor
final class NotificationRequestDetailsTests: XCTestCase {
    func testReloadClearsPreviousDetailsUntilCurrentResponseArrives() async throws {
        let state = AppState()
        let details = NotificationRequestDetails()
        let first = try request(id: 1)
        await details.load(
            configuration: state.serviceConfigurationID,
            currentConfiguration: { state.serviceConfigurationID }, fetch: { first }
        )
        XCTAssertEqual(details.request?.id, 1)
        let fetch = DelayedNotificationRequest()
        let reload = Task {
            await details.load(
                configuration: state.serviceConfigurationID,
                currentConfiguration: { state.serviceConfigurationID }, fetch: { try await fetch.load() }
            )
        }
        await fetch.waitForStart()

        XCTAssertNil(details.request)
        try fetch.complete(.success(request(id: 2)))
        await reload.value
        XCTAssertEqual(details.request?.id, 2)
    }

    func testCurrentFailureShowsError() async {
        let state = AppState()
        let details = NotificationRequestDetails()

        await details.load(
            configuration: state.serviceConfigurationID,
            currentConfiguration: { state.serviceConfigurationID }, fetch: { throw URLError(.timedOut) }
        )

        XCTAssertNotNil(details.errorMessage)
        XCTAssertNil(details.request)
    }

    func testConfigurationChangeRejectsInFlightResponse() async throws {
        let state = AppState()
        let details = NotificationRequestDetails()
        let fetch = DelayedNotificationRequest()
        let load = Task {
            await details.load(
                configuration: state.serviceConfigurationID,
                currentConfiguration: { state.serviceConfigurationID }, fetch: { try await fetch.load() }
            )
        }
        await fetch.waitForStart()
        state.logout()

        try fetch.complete(.success(request(id: 1)))
        await load.value

        XCTAssertNil(details.request)
        XCTAssertNil(details.errorMessage)
    }

    func testConfigurationChangeRejectsInFlightError() async {
        let state = AppState()
        let details = NotificationRequestDetails()
        let fetch = DelayedNotificationRequest()
        let load = Task {
            await details.load(
                configuration: state.serviceConfigurationID,
                currentConfiguration: { state.serviceConfigurationID }, fetch: { try await fetch.load() }
            )
        }
        await fetch.waitForStart()
        state.logout()

        fetch.complete(.failure(URLError(.timedOut)))
        await load.value

        XCTAssertNil(details.request)
        XCTAssertNil(details.errorMessage)
    }

    private func request(id: Int) throws -> MediaRequest {
        let data = Data("""
        {"id":\(id),"status":1,"createdAt":"","updatedAt":"","type":"movie","is4k":false,
         "media":{"id":1},"requestedBy":{"id":1}}
        """.utf8)
        return try JSONDecoder().decode(MediaRequest.self, from: data)
    }
}

@MainActor
private final class DelayedNotificationRequest {
    private var continuation: CheckedContinuation<MediaRequest, Error>?
    private var startWaiter: CheckedContinuation<Void, Never>?

    func load() async throws -> MediaRequest {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            startWaiter?.resume()
            startWaiter = nil
        }
    }

    func waitForStart() async {
        if continuation != nil { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func complete(_ result: Result<MediaRequest, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
