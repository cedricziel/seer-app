@testable import JellyfinClient
import os
import XCTest

@MainActor
final class BonjourDiscoveryTests: XCTestCase {
    func testEmitsDiscoveredServerWithin1500ms() async throws {
        let stub = StubBonjourEngine()
        let discovery = BonjourDiscovery(engine: stub)
        discovery.start()

        let server = Self.makeServer(name: "macmini")
        stub.simulate(.discovered(server))

        try await Self.waitFor(timeout: 1.5) {
            !discovery.discoveredServers.isEmpty
        }

        XCTAssertEqual(discovery.discoveredServers.count, 1)
        XCTAssertEqual(discovery.discoveredServers.first?.host, "macmini.local")
    }

    func testStopsBrowserOnDeinit() async throws {
        let stub = StubBonjourEngine()

        do {
            let discovery = BonjourDiscovery(engine: stub)
            discovery.start()
            XCTAssertFalse(stub.didCancel)
            _ = discovery
        }

        try await Self.waitFor(timeout: 1.0) { stub.didCancel }
        XCTAssertTrue(stub.didCancel)
    }

    func testPermissionDeniedFlag() async throws {
        let stub = StubBonjourEngine()
        let discovery = BonjourDiscovery(engine: stub)
        discovery.start()

        stub.simulate(.permissionDenied)

        try await Self.waitFor(timeout: 1.0) { discovery.permissionDenied }

        XCTAssertTrue(discovery.permissionDenied)
        XCTAssertTrue(discovery.discoveredServers.isEmpty)
    }

    func testRestartIsIdempotent() {
        let stub = StubBonjourEngine()
        let discovery = BonjourDiscovery(engine: stub)

        discovery.start()
        discovery.start()
        XCTAssertEqual(stub.startCallCount, 1, "Repeated start() should be idempotent")

        discovery.stop()
        XCTAssertTrue(stub.didCancel)

        stub.didCancel = false
        discovery.start()
        XCTAssertEqual(stub.startCallCount, 2, "Restart after stop() should re-engage the engine")
    }

    // MARK: - Helpers

    private static func makeServer(name: String, port: Int = 8096) -> DiscoveredJellyfinServer {
        let host = "\(name).local"
        return DiscoveredJellyfinServer(
            id: name,
            name: name,
            host: host,
            port: port,
            url: URL(string: "http://\(host):\(port)")!
        )
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

// MARK: - Stub engine

final class StubBonjourEngine: BonjourEngine {
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
        get { state.withLock { $0.didCancel } }
        set { state.withLock { $0.didCancel = newValue } }
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
