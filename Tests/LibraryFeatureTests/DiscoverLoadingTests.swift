import Foundation
import os
@testable import SeerApp
import SeerCore
import SwiftData
import XCTest

@MainActor
final class DiscoverLoadingTests: XCTestCase {
    private var container: ModelContainer!
    private var state: AppState!
    private var session: URLSession!
    private var first: ServerConfiguration!
    private var second: ServerConfiguration!

    override func setUp() async throws {
        DiscoverRequestTrap.state.withLock { $0 = .init() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DiscoverRequestTrap.self]
        session = URLSession(configuration: configuration)
        let schema = Schema([ServerConfiguration.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        first = ServerConfiguration(
            name: "First", jellyfinURL: URL(string: "https://first.invalid")!,
            jellyseerrURL: URL(string: "https://first.invalid")!, jellyfinUserID: "test-user", isActive: true
        )
        second = ServerConfiguration(name: "Second", jellyfinURL: URL(string: "https://second.invalid")!)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        state = AppState()
        state.setModelContext(container.mainContext)
        state.saveJellyfinCredentials(
            serverID: first.id,
            accessToken: "old-test-token",
            userID: "test-user",
            deviceID: "test"
        )
        state.saveJellyseerrCredentials(serverID: first.id, apiKey: "first-test-key")
        state.setJellyseerrPermissions(1)
        XCTAssertEqual(state.jellyfinAccessToken, "old-test-token")
        XCTAssertEqual(state.jellyseerrAPIKey, "first-test-key")
    }

    override func tearDown() async throws {
        KeychainManager.shared.deleteServerCredentials(for: first.id)
        KeychainManager.shared.deleteServerCredentials(for: second.id)
        DiscoverRequestTrap.finishPending(succeed: false)
        session.invalidateAndCancel()
        session = nil
        state = nil
        container = nil
    }

    func testTotalFailureShowsErrorAndRetryRecovers() async {
        let model = DiscoverViewModel(appState: state, session: session)

        await model.loadInitialData()

        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.hasContent)
        XCTAssertFalse(model.isLoading)
        DiscoverRequestTrap.state.withLock { $0.succeed = true }

        await model.refresh()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.trending.map(\.id), [1])
        XCTAssertFalse(model.isLoading)
    }

    func testPartialFailurePreservesSuccessfulSectionsAndRetryClearsError() async {
        DiscoverRequestTrap.state.withLock { $0.trendingOnly = true }
        let model = DiscoverViewModel(appState: state, session: session)

        await model.loadInitialData()

        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.hasContent)
        XCTAssertEqual(model.trending.map(\.id), [1])
        XCTAssertTrue(model.upcomingMovies.isEmpty)
        DiscoverRequestTrap.state.withLock { $0.succeed = true }

        await model.refresh()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.trending.map(\.id), [1])
        XCTAssertEqual(model.upcomingMovies.map(\.id), [1])
    }

    func testOneGenreFailureKeepsOtherGenresAvailable() async {
        DiscoverRequestTrap.state.withLock {
            $0.succeed = true
            $0.failedPath = "/api/v1/discover/genreslider/tv"
        }
        let model = DiscoverViewModel(appState: state, session: session)

        await model.loadInitialData()

        XCTAssertEqual(model.movieGenres.map(\.id), [1])
        XCTAssertTrue(model.tvGenres.isEmpty)
        XCTAssertEqual(model.errorMessage, "Couldn't load TV Genres. Check your connection and try again.")
    }

    func testFailedRefreshRetainsPreviouslyLoadedContent() async {
        DiscoverRequestTrap.state.withLock { $0.succeed = true }
        let model = DiscoverViewModel(appState: state, session: session)
        await model.loadInitialData()
        DiscoverRequestTrap.state.withLock { $0.succeed = false }

        await model.refresh()

        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.trending.map(\.id), [1])
        XCTAssertEqual(model.upcomingMovies.map(\.id), [1])
    }

    func testOldServerFailureCannotReplaceSuccessfulRetry() async throws {
        DiscoverRequestTrap.state.withLock { $0.hold = true }
        let model = DiscoverViewModel(appState: state, session: session)
        let old = Task { await model.loadInitialData() }
        await DiscoverRequestTrap.waitForPending()
        state.switchServer(to: second.id)
        try state.saveJellyseerrCredentials(
            serverURL: XCTUnwrap(URL(string: "https://second.invalid")),
            apiKey: "second-test-key", permissions: 1
        )
        DiscoverRequestTrap.state.withLock { $0.succeed = true }

        await model.loadInitialData()
        DiscoverRequestTrap.finishPending(succeed: false)
        await old.value

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.trending.map(\.id), [2])
        XCTAssertFalse(model.isLoading)
    }

    func testOldConfigurationSuccessCannotRestoreContentAfterCredentialsChange() async {
        DiscoverRequestTrap.state.withLock { $0.hold = true }
        let model = DiscoverViewModel(appState: state, session: session)
        let old = Task { await model.loadInitialData() }
        await DiscoverRequestTrap.waitForPending()
        state.saveJellyseerrCredentials(serverID: first.id, apiKey: "renewed-test-key", permissions: 1)

        await model.loadInitialData()
        DiscoverRequestTrap.finishPending(succeed: true)
        await old.value

        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.hasContent)
        XCTAssertFalse(model.isLoading)
    }
}

private final class DiscoverRequestTrap: URLProtocol, @unchecked Sendable {
    struct State {
        var hold = false
        var pending: [DiscoverRequestTrap] = []
        var waiter: XCTestExpectation?
        var failedPath: String?
        var succeed = false
        var trendingOnly = false
    }

    static let state = OSAllocatedUnfairLock(initialState: State())

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static func waitForPending() async {
        let expectation = XCTestExpectation(description: "All five Discover requests reached isolated transport")
        state.withLock {
            if $0.pending.count == 5 { expectation.fulfill() } else { $0.waiter = expectation }
        }
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed)
    }

    static func finishPending(succeed: Bool) {
        let pending = state.withLock {
            let pending = $0.pending
            $0.pending = []
            $0.hold = false
            return pending
        }
        pending.forEach { $0.complete(succeed: succeed) }
    }

    override func startLoading() {
        let held = Self.state.withLock {
            guard $0.hold, request.value(forHTTPHeaderField: "X-Api-Key") == "first-test-key" else { return false }
            $0.pending.append(self)
            if $0.pending.count == 5 { $0.waiter?.fulfill(); $0.waiter = nil }
            return true
        }
        if held { return }
        let succeeds = Self.state.withLock {
            ($0.succeed || ($0.trendingOnly && request.url?.path.hasSuffix("/trending") == true))
                && request.url?.path != $0.failedPath
        }
        complete(succeed: succeeds)
    }

    private func complete(succeed: Bool) {
        guard succeed else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let id = request.url?.host == "second.invalid" ? 2 : 1
        let body = request.url?.path.contains("genreslider") == true
            ? #"[{"id":1,"name":"Drama"}]"#
            : #"""
            {"page":1,"totalPages":1,"totalResults":1,
             "results":[{"id":\#(id),"mediaType":"movie","title":"Test"}]}
            """#
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
