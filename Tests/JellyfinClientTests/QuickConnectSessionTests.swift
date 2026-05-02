@testable import JellyfinClient
import os
import XCTest

@MainActor
final class QuickConnectSessionTests: XCTestCase {
    private let serverURL = URL(string: "http://example.local:8096")!

    // MARK: - Pure-function backoff

    func testPollingCadenceBackoffAt30s() {
        XCTAssertEqual(QuickConnectSession.nextPollInterval(elapsed: .seconds(0)), .seconds(1))
        XCTAssertEqual(QuickConnectSession.nextPollInterval(elapsed: .seconds(15)), .seconds(1))
        XCTAssertEqual(QuickConnectSession.nextPollInterval(elapsed: .seconds(30)), .seconds(1))
        XCTAssertEqual(QuickConnectSession.nextPollInterval(elapsed: .seconds(31)), .seconds(3))
        XCTAssertEqual(QuickConnectSession.nextPollInterval(elapsed: .seconds(120)), .seconds(3))
    }

    // MARK: - State machine

    func testQuickConnectDisabledFallsBackImmediately() async {
        let transport = ScriptedTransport(isEnabled: .success(false))
        let session = QuickConnectSession(serverURL: serverURL, transport: transport, clock: FakeClock())

        await session.start()

        XCTAssertEqual(session.state, .failed(.notEnabled))
        XCTAssertEqual(transport.initiateCallCount, 0)
    }

    func testApprovedFlowExchangesSecretForToken() async throws {
        let auth = Self.makeAuthResponse(token: "TOKEN-1", userID: "user-1")
        let transport = ScriptedTransport(
            isEnabled: .success(true),
            initiate: .success(QuickConnectInitiateResponse(code: "ABC123", secret: "SECRET-1")),
            stateScript: [
                .success(QuickConnectStateResponse(authenticated: false)),
                .success(QuickConnectStateResponse(authenticated: false)),
                .success(QuickConnectStateResponse(authenticated: true))
            ],
            authenticate: .success(auth)
        )
        let session = QuickConnectSession(serverURL: serverURL, transport: transport, clock: FakeClock())

        let task = Task { await session.start() }

        try await Self.waitFor(timeout: 2.0) {
            if case .approved = session.state { return true }
            return false
        }

        await task.value
        XCTAssertEqual(transport.authenticateCallCount, 1)
        if case let .approved(authResp) = session.state {
            XCTAssertEqual(authResp.accessToken, "TOKEN-1")
            XCTAssertEqual(authResp.user.id, "user-1")
        } else {
            XCTFail("Expected .approved state, got \(session.state)")
        }
    }

    func testExpiryStopsPolling() async throws {
        let transport = ScriptedTransport(
            isEnabled: .success(true),
            initiate: .success(QuickConnectInitiateResponse(code: "XYZ789", secret: "SECRET-2")),
            stateScript: [], // never returns approved; always pending
            authenticate: .success(Self.makeAuthResponse())
        )
        transport.defaultStateResponse = QuickConnectStateResponse(authenticated: false)

        let session = QuickConnectSession(
            serverURL: serverURL,
            transport: transport,
            clock: FakeClock(),
            timeout: .seconds(5)
        )

        let task = Task { await session.start() }

        try await Self.waitFor(timeout: 2.0) { session.state == .expired }

        await task.value
        XCTAssertEqual(session.state, .expired)
        XCTAssertEqual(transport.authenticateCallCount, 0)
    }

    func testCancelStopsPollingAndDoesNotExchange() async throws {
        let transport = ScriptedTransport(
            isEnabled: .success(true),
            initiate: .success(QuickConnectInitiateResponse(code: "AAA111", secret: "SECRET-3")),
            stateScript: [],
            authenticate: .success(Self.makeAuthResponse())
        )
        transport.defaultStateResponse = QuickConnectStateResponse(authenticated: false)

        // StaticClock paces iterations with real time without advancing virtual
        // time, so the session stays in .pending long enough to be observed and
        // cancelled.
        let session = QuickConnectSession(serverURL: serverURL, transport: transport, clock: StaticClock())

        let task = Task { await session.start() }

        try await Self.waitFor(timeout: 1.0) {
            if case .pending = session.state { return true }
            return false
        }

        session.cancel()
        await task.value

        XCTAssertEqual(session.state, .cancelled)
        XCTAssertEqual(transport.authenticateCallCount, 0)
    }

    func testStateMachineExposesPendingApprovedExpiredFailedCancelled() {
        // Smoke test that all five terminal/intermediate states are constructible
        // and Equatable distinguishes them.
        let auth = Self.makeAuthResponse()
        let states: [QuickConnectSession.State] = [
            .idle,
            .pending(code: "C", secret: "S"),
            .approved(auth),
            .expired,
            .failed(.notEnabled),
            .cancelled
        ]

        for (outer, state) in states.enumerated() {
            for (inner, other) in states.enumerated() where outer != inner {
                XCTAssertNotEqual(state, other, "States at \(outer) and \(inner) should differ")
            }
        }
    }

    // MARK: - Helpers

    private static func makeAuthResponse(token: String = "T", userID: String = "U") -> AuthResponse {
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
            fatalError("Failed to construct AuthResponse fixture: \(error)")
        }
    }

    private static func waitFor(
        timeout: TimeInterval,
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition not met within \(timeout)s")
    }
}

// MARK: - Scripted transport

final class ScriptedTransport: QuickConnectTransport {
    private struct State {
        var stateScript: [Result<QuickConnectStateResponse, Error>]
        var defaultStateResponse: QuickConnectStateResponse?
        var initiateCallCount = 0
        var stateCallCount = 0
        var authenticateCallCount = 0
    }

    private let isEnabledResult: Result<Bool, Error>
    private let initiateResult: Result<QuickConnectInitiateResponse, Error>?
    private let authenticateResult: Result<AuthResponse, Error>?
    private let mutableState: OSAllocatedUnfairLock<State>

    init(
        isEnabled: Result<Bool, Error> = .success(true),
        initiate: Result<QuickConnectInitiateResponse, Error>? = nil,
        stateScript: [Result<QuickConnectStateResponse, Error>] = [],
        authenticate: Result<AuthResponse, Error>? = nil
    ) {
        isEnabledResult = isEnabled
        initiateResult = initiate
        authenticateResult = authenticate
        mutableState = OSAllocatedUnfairLock(initialState: State(stateScript: stateScript))
    }

    var defaultStateResponse: QuickConnectStateResponse? {
        get { mutableState.withLock { $0.defaultStateResponse } }
        set { mutableState.withLock { $0.defaultStateResponse = newValue } }
    }

    var initiateCallCount: Int {
        mutableState.withLock { $0.initiateCallCount }
    }

    var stateCallCount: Int {
        mutableState.withLock { $0.stateCallCount }
    }

    var authenticateCallCount: Int {
        mutableState.withLock { $0.authenticateCallCount }
    }

    func isEnabled(serverURL _: URL) async throws -> Bool {
        try isEnabledResult.get()
    }

    func initiate(serverURL _: URL) async throws -> QuickConnectInitiateResponse {
        mutableState.withLock { $0.initiateCallCount += 1 }
        guard let result = initiateResult else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        return try result.get()
    }

    func pollState(serverURL _: URL, secret _: String) async throws -> QuickConnectStateResponse {
        let action: PollAction = mutableState.withLock { state in
            state.stateCallCount += 1
            if !state.stateScript.isEmpty {
                return .scripted(state.stateScript.removeFirst())
            }
            return .fallback(state.defaultStateResponse)
        }
        switch action {
        case let .scripted(result):
            return try result.get()
        case let .fallback(value):
            if let value { return value }
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
    }

    func authenticate(serverURL _: URL, secret _: String) async throws -> AuthResponse {
        mutableState.withLock { $0.authenticateCallCount += 1 }
        guard let result = authenticateResult else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        return try result.get()
    }

    private enum PollAction {
        case scripted(Result<QuickConnectStateResponse, Error>)
        case fallback(QuickConnectStateResponse?)
    }
}

// MARK: - Fake clock

final class FakeClock: QuickConnectClock {
    private struct State {
        let baseInstant = ContinuousClock.Instant.now
        var elapsedNanos: Int64 = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func now() -> ContinuousClock.Instant {
        state.withLock { state in
            state.baseInstant.advanced(by: .nanoseconds(state.elapsedNanos))
        }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        let nanos = duration.components.seconds * 1_000_000_000
            + duration.components.attoseconds / 1_000_000_000
        state.withLock { $0.elapsedNanos += nanos }
        await Task.yield()
    }
}

// MARK: - Static clock

/// Returns the real current time and paces sleeps with a small real delay,
/// without advancing any virtual clock. Useful for tests that need to observe
/// intermediate states (.pending) without racing against virtual expiry.
final class StaticClock: QuickConnectClock {
    func now() -> ContinuousClock.Instant {
        .now
    }

    func sleep(for _: Duration) async throws {
        try await Task.sleep(for: .milliseconds(20))
    }
}
