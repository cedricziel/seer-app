import Combine
import JellyfinClient
import os
@testable import SeerApp
import SeerCore
@testable import SeerUI
import SwiftData
import XCTest

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var appState: AppState!
    private var onboardingManager: OnboardingManager!
    private var modelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        // In-memory SwiftData container so tests don't touch the user's
        // CloudKit-backed store.
        let schema = Schema([ServerConfiguration.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        appState = AppState()
        appState.setModelContext(ModelContext(modelContainer))
        onboardingManager = OnboardingManager()
        // Reset OnboardingManager flags so each test starts clean.
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isFirstLaunchAfterSetup")
        UserDefaults.standard.removeObject(forKey: "lastSeenWhatsNewVersion")
    }

    override func tearDown() async throws {
        appState = nil
        onboardingManager = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - 8.4 / 8.5 — Quick Connect availability routing

    func testQuickConnectShownWhenServerEnabled() async throws {
        let model = makeModel(
            quickConnectEnabled: true,
            serverInfoResult: .success(makeServerInfo())
        )
        await Self.runManualEntry(model: model, url: "https://server.example.com")

        try await Self.waitFor(timeout: 2.0) {
            if case .quickConnect = model.phase {
                return true
            }
            return false
        }
        if case let .quickConnect(host) = model.phase {
            XCTAssertEqual(host, "MacMini")
        } else {
            XCTFail("Expected .quickConnect phase, got \(model.phase)")
        }
    }

    func testQuickConnectFallbackToPasswordWhenDisabled() async throws {
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .success(makeServerInfo())
        )
        await Self.runManualEntry(model: model, url: "https://server.example.com")

        try await Self.waitFor(timeout: 1.0) {
            if case .password = model.phase {
                return true
            }
            return false
        }
        if case let .password(host) = model.phase {
            XCTAssertEqual(host, "MacMini")
        } else {
            XCTFail("Expected .password phase, got \(model.phase)")
        }
    }

    // MARK: - 8.6 / 8.7 — Completion path

    func testCompletionRoutesToLibraryWithoutCelebrationPage() async throws {
        let auth = Self.makeAuthResponse(token: "T1", userID: "U1")
        let authenticator: OnboardingViewModel.PasswordAuthenticator = { _, _, _ in
            OnboardingViewModel.PasswordAuthResult(response: auth, deviceID: "device-1")
        }
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .success(makeServerInfo()),
            passwordAuthenticator: authenticator
        )

        await Self.runManualEntry(model: model, url: "https://server.example.com")
        try await Self.waitFor(timeout: 1.0) {
            if case .password = model.phase {
                return true
            }
            return false
        }

        model.passwordUsername = "tester"
        model.passwordPassword = "pw"
        await model.submitPassword()

        XCTAssertTrue(appState.isAuthenticated, "Should authenticate after submitPassword")
        XCTAssertEqual(model.phase, .completing)
    }

    func testFirstLaunchTipFlagSetAfterStreamlinedFlow() async throws {
        let auth = Self.makeAuthResponse(token: "T1", userID: "U1")
        let authenticator: OnboardingViewModel.PasswordAuthenticator = { _, _, _ in
            OnboardingViewModel.PasswordAuthResult(response: auth, deviceID: "device-1")
        }
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .success(makeServerInfo()),
            passwordAuthenticator: authenticator
        )

        await Self.runManualEntry(model: model, url: "https://server.example.com")
        try await Self.waitFor(timeout: 1.0) {
            if case .password = model.phase {
                return true
            }
            return false
        }

        model.passwordUsername = "tester"
        model.passwordPassword = "pw"
        await model.submitPassword()

        XCTAssertTrue(
            onboardingManager.isFirstLaunchAfterSetup,
            "Streamlined onboarding must set the first-launch tip flag"
        )
    }

    // MARK: - 8.8 / 8.10 — Manual entry validation

    func testManualEntryRejectsNonJellyfinURL() async {
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .failure(ServerInfoFetcher.ServerInfoError.notJellyfin)
        )

        model.tapManualEntry()
        model.manualURL = "https://not-jellyfin.example.com"
        await model.validateManualURLAndAdvance()

        XCTAssertEqual(model.phase, .manualEntry, "Should stay on manual entry on validation failure")
        XCTAssertNotNil(model.manualURLError)
        XCTAssertEqual(
            model.manualURL,
            "https://not-jellyfin.example.com",
            "URL should be preserved after rejection"
        )
    }

    func testManualEntryFailurePreservesEnteredURL() async {
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .failure(URLError(.cannotFindHost))
        )

        model.tapManualEntry()
        model.manualURL = "https://offline.example.com"
        await model.validateManualURLAndAdvance()

        XCTAssertEqual(model.phase, .manualEntry)
        XCTAssertNotNil(model.manualURLError)
        XCTAssertEqual(
            model.manualURL,
            "https://offline.example.com",
            "URL must remain in the field after a network failure"
        )
    }

    // MARK: - 8.9 — Quick Connect expiry preserves server

    func testQuickConnectFailureClearsCodeAndRetryKeepsSelectedServer() async throws {
        let failed = ScriptedQuickConnectTransport(
            isEnabledResult: .success(true),
            initiateResult: .success(.init(code: "OLD123", secret: "old-secret"))
        )
        let replacement = SuspendedQuickConnectTransport()
        defer { replacement.initiation?.resume(throwing: CancellationError()) }
        var nextTransport: any QuickConnectTransport = failed
        let model = makeModel(
            quickConnectEnabled: true,
            serverInfoResult: .success(makeServerInfo()),
            quickConnectTransportFactory: { _ in nextTransport }
        )
        defer { model.stop() }
        await Self.runManualEntry(model: model, url: "https://server.example.com")
        try await Self.waitFor(timeout: 1) { model.quickConnectError != nil }
        let selected = model.selectedServer
        XCTAssertEqual(model.quickConnectError, "Network error: Server returned an unexpected response.")
        XCTAssertNil(model.quickConnectCode)
        XCTAssertFalse(model.quickConnectIsPolling)

        nextTransport = replacement
        let retry = Task { await model.switchToQuickConnect() }
        try await Self.waitFor(timeout: 1) { replacement.initiation != nil }
        XCTAssertNil(model.quickConnectCode)
        XCTAssertNil(model.quickConnectError)
        XCTAssertTrue(model.quickConnectIsPolling)
        try XCTUnwrap(replacement.initiation).resume(returning: .init(code: "NEW456", secret: "new-secret"))
        replacement.initiation = nil
        await retry.value
        try await Self.waitFor(timeout: 1) { model.quickConnectCode == "NEW456" }

        XCTAssertNil(model.quickConnectError)
        XCTAssertTrue(model.quickConnectIsPolling)
        XCTAssertEqual(model.selectedServer, selected)
        XCTAssertEqual(model.phase, .quickConnect(serverDisplay: "MacMini"))
    }

    func testQuickConnectExpiryClearsCodeAndPreservesServer() async throws {
        let transport = ScriptedQuickConnectTransport(
            isEnabledResult: .success(true),
            initiateResult: .success(.init(code: "OLD123", secret: "old-secret"))
        )
        transport.defaultStateResponse = .init(authenticated: false)
        let model = makeModel(
            quickConnectEnabled: true,
            serverInfoResult: .success(makeServerInfo()),
            quickConnectTransportFactory: { _ in transport },
            quickConnectTimeout: .zero
        )
        defer { model.stop() }
        await Self.runManualEntry(model: model, url: "https://server.example.com")
        try await Self.waitFor(timeout: 1) { model.quickConnectError != nil }

        XCTAssertEqual(model.quickConnectError, "Code expired. Request a new code to try again.")
        XCTAssertNil(model.quickConnectCode)
        XCTAssertFalse(model.quickConnectIsPolling)
        XCTAssertEqual(model.selectedServer?.url, URL(string: "https://server.example.com"))
        XCTAssertEqual(model.phase, .quickConnect(serverDisplay: "MacMini"))
    }

    func testLeavingQuickConnectDiscardsQueuedSessionUpdates() async {
        let transport = ScriptedQuickConnectTransport(
            isEnabledResult: .success(true),
            initiateResult: .success(.init(code: "OLD123", secret: "old-secret"))
        )
        transport.defaultStateResponse = .init(authenticated: false)
        let model = makeModel(
            quickConnectEnabled: true,
            serverInfoResult: .success(makeServerInfo()),
            quickConnectTransportFactory: { _ in transport }
        )
        defer { model.stop() }
        await Self.runManualEntry(model: model, url: "https://server.example.com")
        model.switchToPassword()
        await Task.yield()

        XCTAssertEqual(model.phase, .password(serverDisplay: "MacMini"))
        XCTAssertFalse(model.quickConnectIsPolling)
        XCTAssertNil(model.quickConnectCode)
        XCTAssertNil(model.quickConnectError)
        XCTAssertFalse(appState.isAuthenticated)
    }

    func testCancellingWhileRequestingCodeIgnoresLateResponse() async throws {
        let transport = SuspendedQuickConnectTransport()
        defer { transport.initiation?.resume(throwing: CancellationError()) }
        let model = makeModel(
            quickConnectEnabled: true,
            serverInfoResult: .success(makeServerInfo()),
            quickConnectTransportFactory: { _ in transport }
        )
        defer { model.stop() }
        let request = Task {
            await Self.runManualEntry(model: model, url: "https://server.example.com")
        }
        try await Self.waitFor(timeout: 1) { transport.initiation != nil }
        XCTAssertNil(model.quickConnectCode)
        XCTAssertTrue(model.quickConnectIsPolling)

        model.cancelQuickConnect()
        try XCTUnwrap(transport.initiation).resume(returning: .init(code: "LATE12", secret: "late-secret"))
        transport.initiation = nil
        await request.value
        await Task.yield()

        XCTAssertEqual(model.phase, .welcome)
        XCTAssertNil(model.quickConnectCode)
        XCTAssertNil(model.quickConnectError)
        XCTAssertFalse(model.quickConnectIsPolling)
        XCTAssertFalse(appState.isAuthenticated)
    }

    // MARK: - 8.11 — Bonjour acceptance stores server selection

    func testBonjourAcceptanceStoresInternalURL() async throws {
        let stub = StubBonjourEngine()
        let bonjour = BonjourDiscovery(engine: stub)
        let model = makeModel(
            quickConnectEnabled: false,
            bonjour: bonjour,
            passwordAuthenticator: { _, _, _ in
                .init(response: Self.makeAuthResponse(), deviceID: "bonjour-test-device")
            }
        )
        defer { model.stop() }
        model.start()

        let server = try DiscoveredJellyfinServer(
            id: "macmini",
            name: "macmini",
            host: "macmini.local",
            port: 8096,
            url: XCTUnwrap(URL(string: "http://macmini.local:8096"))
        )
        stub.simulate(.discovered(server))

        try await Self.waitFor(timeout: 1.0) {
            !bonjour.discoveredServers.isEmpty
        }

        let viewSuggestion = WelcomeView.Suggestion(
            id: "bonjour-macmini",
            title: "macmini",
            subtitle: "macmini.local · on this Wi-Fi",
            symbolName: "wifi"
        )
        model.selectSuggestion(viewSuggestion)

        try await Self.waitFor(timeout: 1.0) {
            model.selectedServer != nil
        }

        XCTAssertEqual(model.selectedServer?.url, URL(string: "http://macmini.local:8096"))
        XCTAssertTrue(
            model.selectedServer?.discoveredViaBonjour ?? false,
            "Bonjour-discovered servers must be flagged for dual-URL learning"
        )

        try await Self.waitFor(timeout: 1) {
            model.phase == .password(serverDisplay: "macmini")
        }
        model.passwordUsername = "tester"
        await model.submitPassword()

        XCTAssertEqual(appState.servers.count, 1)
        XCTAssertEqual(appState.activeServer?.jellyfinURL, server.url)
        XCTAssertNil(appState.activeServer?.internalJellyfinURL)
    }

    // MARK: - 8.12 — Onboarding completes without Jellyseerr

    func testOnboardingCompletesWithoutJellyseerr() async throws {
        let auth = Self.makeAuthResponse()
        let authenticator: OnboardingViewModel.PasswordAuthenticator = { _, _, _ in
            OnboardingViewModel.PasswordAuthResult(response: auth, deviceID: "device-x")
        }
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .success(makeServerInfo()),
            passwordAuthenticator: authenticator
        )

        await Self.runManualEntry(model: model, url: "https://server.example.com")
        try await Self.waitFor(timeout: 1.0) {
            if case .password = model.phase {
                return true
            }
            return false
        }

        model.passwordUsername = "tester"
        model.passwordPassword = "pw"
        await model.submitPassword()

        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNil(
            appState.jellyseerrServerURL,
            "Jellyseerr must not be configured by the streamlined onboarding flow"
        )
        XCTAssertNil(
            appState.jellyseerrAPIKey,
            "No Jellyseerr API key should have been written"
        )
    }

    func testPasswordSignInPreservesSavedServerIdentityAndSettings() async throws {
        try await assertReauthenticationPreservesSavedServer(quickConnect: false)
    }

    func testQuickConnectPreservesSyncedServerIdentityAndSettings() async throws {
        try await assertReauthenticationPreservesSavedServer(quickConnect: true)
    }

    func testQuickConnectRetryPreservesSyncedServerIdentityAndSettings() async throws {
        try await assertReauthenticationPreservesSavedServer(quickConnect: true, retryQuickConnect: true)
    }

    private func assertReauthenticationPreservesSavedServer(
        quickConnect: Bool,
        retryQuickConnect: Bool = false
    ) async throws {
        let original = try ServerConfiguration(
            name: "Saved server",
            emoji: "🎬",
            jellyfinURL: XCTUnwrap(URL(string: "https://saved.example.com")),
            jellyseerrURL: URL(string: "https://requests.example.com"),
            jellyfinUserID: "old-user",
            createdAt: Date(timeIntervalSince1970: 123),
            internalJellyfinURL: URL(string: "http://192.168.1.20:8096"),
            internalNetworkSSIDs: ["Home"]
        )
        appState.addServer(original)
        let originalID = original.id
        let auth = Self.makeAuthResponse(token: "new-token", userID: "new-user")
        let transport = ScriptedQuickConnectTransport(
            isEnabledResult: .success(quickConnect),
            initiateResult: .success(.init(code: "TEST12", secret: "test-secret")),
            authenticateResult: .success(auth)
        )
        transport.defaultStateResponse = .init(authenticated: true)
        var selectedTransport = retryQuickConnect
            ? ScriptedQuickConnectTransport(isEnabledResult: .success(true))
            : transport
        let model = makeModel(
            quickConnectEnabled: quickConnect,
            serverInfoResult: .success(makeServerInfo()),
            quickConnectTransportFactory: { _ in selectedTransport },
            passwordAuthenticator: { _, _, _ in
                .init(response: auth, deviceID: "test-device")
            }
        )
        defer { model.stop() }
        try model.selectSuggestion(XCTUnwrap(model.welcomeSuggestions.primary))
        if quickConnect {
            if retryQuickConnect {
                try await Self.waitFor(timeout: 1) { model.quickConnectError != nil }
                selectedTransport = transport
                await model.switchToQuickConnect()
            }
            try await Self.waitFor(timeout: 2) { self.appState.isAuthenticated }
        } else {
            try await Self.waitFor(timeout: 1) {
                model.phase == .password(serverDisplay: "Saved server")
            }
            model.passwordUsername = "tester"
            await model.submitPassword()
        }

        XCTAssertEqual(appState.servers.count, 1)
        let saved = try XCTUnwrap(appState.activeServer)
        XCTAssertEqual(saved.id, originalID)
        XCTAssertEqual(saved.name, "Saved server")
        XCTAssertEqual(saved.emoji, "🎬")
        XCTAssertEqual(saved.jellyfinURL, URL(string: "https://saved.example.com"))
        XCTAssertEqual(saved.jellyseerrURL, URL(string: "https://requests.example.com"))
        XCTAssertEqual(saved.createdAt, Date(timeIntervalSince1970: 123))
        XCTAssertEqual(saved.internalJellyfinURL, URL(string: "http://192.168.1.20:8096"))
        XCTAssertEqual(saved.internalNetworkSSIDs, ["Home"])
        XCTAssertEqual(saved.jellyfinUserID, "new-user")
        XCTAssertEqual(appState.jellyfinAccessToken, "new-token")
    }

    func testManualAuthenticationAddsNewServerAlongsideSavedServer() async throws {
        let original = try ServerConfiguration(
            name: "Saved",
            jellyfinURL: XCTUnwrap(URL(string: "https://saved.example.com"))
        )
        appState.addServer(original)
        let model = makeModel(
            quickConnectEnabled: false,
            serverInfoResult: .success(makeServerInfo()),
            passwordAuthenticator: { _, _, _ in
                .init(response: Self.makeAuthResponse(userID: "new-user"), deviceID: "test-device")
            }
        )
        defer { model.stop() }
        await Self.runManualEntry(model: model, url: "https://new.example.com")
        model.passwordUsername = "tester"

        await model.submitPassword()

        XCTAssertEqual(appState.servers.count, 2)
        let added = try XCTUnwrap(appState.activeServer)
        XCTAssertNotEqual(added.id, original.id)
        XCTAssertEqual(added.jellyfinURL, URL(string: "https://new.example.com"))
        XCTAssertEqual(added.internalJellyfinURL, makeServerInfo().localAddress)
        XCTAssertEqual(added.jellyfinUserID, "new-user")
    }

    func testManualValidationIgnoresASecondSubmissionWhileFetching() async {
        let started = expectation(description: "First validation started")
        let secondFinished = expectation(description: "Repeated submission returned")
        let transport = PendingInfoTransport(started: started)
        let model = OnboardingViewModel(
            appState: appState,
            onboardingManager: onboardingManager,
            serverInfoFetcher: ServerInfoFetcher(transport: transport),
            quickConnectTransportFactory: { _ in ScriptedQuickConnectTransport(isEnabledResult: .success(false)) }
        )
        model.tapManualEntry()
        model.manualURL = "https://fixture.invalid"
        let first = Task { await model.validateManualURLAndAdvance() }
        await fulfillment(of: [started], timeout: 1)

        let second = Task {
            await model.validateManualURLAndAdvance()
            secondFinished.fulfill()
        }
        await fulfillment(of: [secondFinished], timeout: 1)
        transport.finish()
        await first.value
        await second.value

        XCTAssertEqual(transport.requestCount, 1)
        XCTAssertFalse(model.isValidatingManualURL)
    }

    // MARK: - Model construction helpers

    private func makeModel(
        quickConnectEnabled: Bool,
        bonjour: BonjourDiscovery? = nil,
        serverInfoResult: Result<ServerInfo, Error>? = nil,
        quickConnectTransportFactory: OnboardingViewModel.QuickConnectTransportFactory? = nil,
        passwordAuthenticator: OnboardingViewModel.PasswordAuthenticator? = nil,
        quickConnectTimeout: Duration = .seconds(600)
    ) -> OnboardingViewModel {
        let factory: OnboardingViewModel.QuickConnectTransportFactory =
            quickConnectTransportFactory ?? { _ in
                ScriptedQuickConnectTransport(isEnabledResult: .success(quickConnectEnabled))
            }
        let fetcher = if let serverInfoResult {
            ServerInfoFetcher(transport: StubInfoTransport(response: serverInfoResult))
        } else {
            ServerInfoFetcher()
        }
        return OnboardingViewModel(
            appState: appState,
            onboardingManager: onboardingManager,
            bonjour: bonjour,
            serverInfoFetcher: fetcher,
            quickConnectTransportFactory: factory,
            passwordAuthenticator: passwordAuthenticator,
            quickConnectTimeout: quickConnectTimeout
        )
    }

    private func makeServerInfo() -> ServerInfo {
        ServerInfo(
            serverID: "abc",
            productName: "Jellyfin Server",
            serverName: "MacMini",
            localAddress: URL(string: "http://192.168.1.10:8096"),
            version: "10.8.13"
        )
    }

    @MainActor
    private static func runManualEntry(model: OnboardingViewModel, url: String) async {
        model.tapManualEntry()
        model.manualURL = url
        await model.validateManualURLAndAdvance()
    }

    fileprivate static func makeAuthResponse(token: String = "T", userID: String = "U") -> AuthResponse {
        let json = Data("""
        {
          "User": {"Id": "\(userID)", "Name": "tester"},
          "AccessToken": "\(token)",
          "ServerId": "server-1"
        }
        """.utf8)
        do {
            return try JSONDecoder().decode(AuthResponse.self, from: json)
        } catch {
            fatalError("Failed to decode AuthResponse fixture: \(error)")
        }
    }

    @MainActor
    private static func waitFor(
        timeout: TimeInterval,
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition not met within \(timeout)s")
    }
}

// MARK: - Test doubles

private final class StubInfoTransport: ServerInfoTransport {
    private let response: Result<Data, Error>

    init(response: Result<ServerInfo, Error>) {
        switch response {
        case let .success(info):
            let payload: [String: Any] = [
                "Id": info.serverID,
                "ProductName": info.productName,
                "ServerName": info.serverName ?? NSNull() as Any,
                "LocalAddress": info.localAddress?.absoluteString ?? NSNull() as Any,
                "Version": info.version ?? NSNull() as Any
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                self.response = .success(data)
            } catch {
                self.response = .failure(error)
            }
        case let .failure(error):
            self.response = .failure(error)
        }
    }

    func fetchPublicInfo(from _: URL) async throws -> Data {
        try response.get()
    }
}

private final class StubBonjourEngine: BonjourEngine {
    private struct State {
        var handler: (@Sendable (BonjourDiscoveryEvent) -> Void)?
        var startCallCount = 0
        var didCancel = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var startCallCount: Int {
        state.withLock { $0.startCallCount }
    }

    var didCancel: Bool {
        state.withLock { $0.didCancel }
    }

    func start(handler: @escaping @Sendable (BonjourDiscoveryEvent) -> Void) {
        state.withLock {
            $0.startCallCount += 1
            $0.handler = handler
        }
    }

    func cancel() {
        state.withLock {
            $0.didCancel = true
            $0.handler = nil
        }
    }

    func simulate(_ event: BonjourDiscoveryEvent) {
        let handler = state.withLock { $0.handler }
        handler?(event)
    }
}

private final class ScriptedQuickConnectTransport: QuickConnectTransport {
    private struct State {
        var stateScript: [Result<QuickConnectStateResponse, Error>] = []
        var defaultStateResponse: QuickConnectStateResponse?
    }

    private let isEnabledResult: Result<Bool, Error>
    private let initiateResult: Result<QuickConnectInitiateResponse, Error>?
    private let authenticateResult: Result<AuthResponse, Error>?
    private let mutableState: OSAllocatedUnfairLock<State>

    init(
        isEnabledResult: Result<Bool, Error>,
        initiateResult: Result<QuickConnectInitiateResponse, Error>? = nil,
        authenticateResult: Result<AuthResponse, Error>? = nil
    ) {
        self.isEnabledResult = isEnabledResult
        self.initiateResult = initiateResult
        self.authenticateResult = authenticateResult
        mutableState = OSAllocatedUnfairLock(initialState: State())
    }

    var defaultStateResponse: QuickConnectStateResponse? {
        get { mutableState.withLock { $0.defaultStateResponse } }
        set { mutableState.withLock { $0.defaultStateResponse = newValue } }
    }

    func isEnabled(serverURL _: URL) async throws -> Bool {
        try isEnabledResult.get()
    }

    func initiate(serverURL _: URL) async throws -> QuickConnectInitiateResponse {
        guard let initiateResult else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        return try initiateResult.get()
    }

    func pollState(serverURL _: URL, secret _: String) async throws -> QuickConnectStateResponse {
        let action: (Result<QuickConnectStateResponse, Error>?, QuickConnectStateResponse?) =
            mutableState.withLock { state in
                if !state.stateScript.isEmpty {
                    return (state.stateScript.removeFirst(), nil)
                }
                return (nil, state.defaultStateResponse)
            }
        if let result = action.0 {
            return try result.get()
        }
        if let fallback = action.1 {
            return fallback
        }
        throw QuickConnectSession.QuickConnectError.invalidResponse
    }

    func authenticate(serverURL _: URL, secret _: String) async throws -> AuthResponse {
        guard let authenticateResult else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        return try authenticateResult.get()
    }
}

@MainActor
private final class SuspendedQuickConnectTransport: QuickConnectTransport {
    var initiation: CheckedContinuation<QuickConnectInitiateResponse, any Error>?

    func isEnabled(serverURL _: URL) async throws -> Bool {
        true
    }

    func initiate(serverURL _: URL) async throws -> QuickConnectInitiateResponse {
        try await withCheckedThrowingContinuation { initiation = $0 }
    }

    func pollState(serverURL _: URL, secret _: String) async throws -> QuickConnectStateResponse {
        .init(authenticated: false)
    }

    func authenticate(serverURL _: URL, secret _: String) async throws -> AuthResponse {
        throw QuickConnectSession.QuickConnectError.invalidResponse
    }
}

private final class PendingInfoTransport: ServerInfoTransport {
    private struct State {
        var continuations: [CheckedContinuation<Data, Error>] = []
        var requestCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let started: XCTestExpectation

    init(started: XCTestExpectation) {
        self.started = started
    }

    var requestCount: Int {
        state.withLock { $0.requestCount }
    }

    func fetchPublicInfo(from _: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.requestCount += 1
                $0.continuations.append(continuation)
            }
            started.fulfill()
        }
    }

    func finish() {
        let continuations = state.withLock {
            let pending = $0.continuations
            $0.continuations = []
            return pending
        }
        for continuation in continuations {
            continuation.resume(throwing: URLError(.cannotConnectToHost))
        }
    }
}
