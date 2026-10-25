import Foundation
import JellyseerrClient
import os
@testable import SeerApp
import SeerCore
import SwiftData
import XCTest

@MainActor
final class ServiceClientLifecycleTests: XCTestCase {
    private var container: ModelContainer!
    private var state: AppState!
    private var first: ServerConfiguration!
    private var second: ServerConfiguration!

    override func setUp() async throws {
        LifecycleRequestTrap.requests.withLock { $0 = [] }
        URLProtocol.registerClass(LifecycleRequestTrap.self)
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
    }

    override func tearDown() async throws {
        LifecycleRequestTrap.completeAuth()
        KeychainManager.shared.deleteServerCredentials(for: first.id)
        KeychainManager.shared.deleteServerCredentials(for: second.id)
        URLProtocol.unregisterClass(LifecycleRequestTrap.self)
        state = nil
        container = nil
    }

    func testDiscoverClearsClientWhenSwitchingToUnconfiguredServer() async throws {
        let model = DiscoverViewModel(appState: state)
        state.switchServer(to: second.id)

        do {
            try await model.requestMedia(movie())
            XCTFail("An unconfigured server must reject requests")
        } catch let error as JellyseerrService.JellyseerrError {
            guard case .notAuthenticated = error else { return XCTFail("Expected missing credentials, got \(error)") }
        }
        XCTAssertTrue(LifecycleRequestTrap.requests.withLock { $0.filter { $0.httpMethod == "POST" }.isEmpty })
    }

    func testDiscoverReconnectFromAnotherTabUsesNewServer() async throws {
        let model = DiscoverViewModel(appState: state)
        state.switchServer(to: second.id)
        try state.saveJellyseerrCredentials(
            serverURL: XCTUnwrap(URL(string: "https://second.invalid")),
            apiKey: "second-test-key"
        )

        try? await model.requestMedia(movie())

        let request = try XCTUnwrap(LifecycleRequestTrap.requests.withLock { $0.last { $0.httpMethod == "POST" } })
        XCTAssertEqual(request.url?.host, "second.invalid")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "second-test-key")
    }

    func testRetainedGenreUsesNewServerForRequests() async throws {
        let model = GenreBrowseViewModel(genre: DiscoverGenre(id: 1, name: "Test"), mediaType: .movie, appState: state)
        state.switchServer(to: second.id)
        try state.saveJellyseerrCredentials(
            serverURL: XCTUnwrap(URL(string: "https://second.invalid")),
            apiKey: "second-test-key"
        )

        try? await model.requestMedia(movie())

        let request = try XCTUnwrap(LifecycleRequestTrap.requests.withLock { $0.last { $0.httpMethod == "POST" } })
        XCTAssertEqual(request.url?.host, "second.invalid")
    }

    func testRetainedGenreClearsPreviousResultsWhenConfigurationChanges() async throws {
        let model = GenreBrowseViewModel(genre: DiscoverGenre(id: 1, name: "Test"), mediaType: .movie, appState: state)
        model.results = try [movie()]
        model.currentPage = 4
        state.switchServer(to: second.id)

        await model.loadInitial()

        XCTAssertTrue(model.results.isEmpty)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertEqual(model.errorMessage, "Jellyseerr not configured")
    }

    func testLibraryReauthenticationUsesNewTokenWithoutServerSwitch() async throws {
        let model = LibraryViewModel(appState: state)
        state.saveJellyfinCredentials(
            serverID: first.id,
            accessToken: "new-test-token",
            userID: "test-user",
            deviceID: "test"
        )

        await model.loadLibraries()

        let request = try XCTUnwrap(LifecycleRequestTrap.requests.withLock { $0.last })
        XCTAssertTrue(try XCTUnwrap(request.value(forHTTPHeaderField: "Authorization")).contains("new-test-token"))
    }

    func testLibraryURLChangeUsesUpdatedEndpoint() async throws {
        let model = LibraryViewModel(appState: state)
        first.jellyfinURL = try XCTUnwrap(URL(string: "https://updated.invalid"))
        state.updateServer(first)

        await model.loadLibraries()

        XCTAssertEqual(LifecycleRequestTrap.requests.withLock { $0.last?.url?.host }, "updated.invalid")
    }

    func testConfigurationIdentityChangesOnReauthentication() {
        let original = state.serviceConfigurationID

        state.saveJellyfinCredentials(
            serverID: first.id,
            accessToken: "new-test-token",
            userID: "test-user",
            deviceID: "test"
        )

        XCTAssertNotEqual(state.serviceConfigurationID, original)
    }

    func testJellyseerrKeyRenewalChangesIdentityAndClearsPermissions() {
        let original = state.serviceConfigurationID

        state.saveJellyseerrCredentials(serverID: first.id, apiKey: "replacement-test-key")

        XCTAssertNotEqual(state.serviceConfigurationID, original)
        XCTAssertEqual(state.jellyseerrUserPermissions, 0)
    }

    func testOldPermissionResponseCannotGrantPermissionsOnNewServer() async throws {
        let model = DiscoverViewModel(appState: state)
        let configurationID = state.serviceConfigurationID
        let service = try JellyseerrService(serverURL: XCTUnwrap(first.jellyseerrURL), apiKey: "first-test-key")
        LifecycleRequestTrap.authState.withLock { $0.hold = true }
        let load = Task { await model.loadUserPermissions(service: service, configurationID: configurationID) }
        await LifecycleRequestTrap.waitForAuth()

        state.switchServer(to: second.id)
        LifecycleRequestTrap.completeAuth()
        await load.value

        XCTAssertEqual(state.jellyseerrUserPermissions, 0)
    }

    private func movie() throws -> SearchResult {
        try JSONDecoder().decode(SearchResult.self, from: Data(#"{"id":1,"mediaType":"movie","title":"Test"}"#.utf8))
    }
}

private final class LifecycleRequestTrap: URLProtocol, @unchecked Sendable {
    static let requests = OSAllocatedUnfairLock(initialState: [URLRequest]())

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    struct AuthState {
        var hold = false
        var pending: LifecycleRequestTrap?
        var waiter: CheckedContinuation<Void, Never>?
    }

    static let authState = OSAllocatedUnfairLock(initialState: AuthState())

    static func waitForAuth() async {
        await withCheckedContinuation { continuation in
            authState.withLock { state in
                if state.pending != nil {
                    continuation.resume()
                } else {
                    state.waiter = continuation
                }
            }
        }
    }

    static func completeAuth() {
        let pending = authState.withLock { state in
            let pending = state.pending
            state = AuthState()
            return pending
        }
        guard let pending, let url = pending.request.url else { return }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data(#"{"id":1,"userType":2,"permissions":2,"createdAt":"","updatedAt":"","requestCount":0}"#.utf8)
        pending.client?.urlProtocol(pending, didReceive: response, cacheStoragePolicy: .notAllowed)
        pending.client?.urlProtocol(pending, didLoad: data)
        pending.client?.urlProtocolDidFinishLoading(pending)
    }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        let held = Self.authState.withLock { state in
            guard state.hold, request.url?.path.hasSuffix("/auth/me") == true else { return false }
            state.pending = self
            state.waiter?.resume()
            state.waiter = nil
            return true
        }
        if !held {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }
    }

    override func stopLoading() {}
}
