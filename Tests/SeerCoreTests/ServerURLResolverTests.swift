import os
@testable import SeerCore
import XCTest

@MainActor
final class ServerURLResolverTests: XCTestCase {
    private let externalURL = URL(string: "https://media.example.com")!
    private let internalURL = URL(string: "http://192.168.1.10:8096")!

    func testReachabilityFallbackUsedWhenSSIDUnknown() async {
        // No SSID known, so the SSID fast path won't apply.
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober, dateProvider: { Date() })

        let config = makeConfig()

        let resolved = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolved, internalURL)
        XCTAssertEqual(prober.callCount, 1)
    }

    func testReachabilityFallbackPrefersExternalWhenInternalUnreachable() async {
        let prober = StubProber(reachable: false)
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober, dateProvider: { Date() })

        let config = makeConfig()

        let resolved = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolved, externalURL)
    }

    func testReachabilityProbeCachedFor60s() async {
        let prober = StubProber(reachable: true)
        let mutableNow = MutableNow(initial: Date(timeIntervalSince1970: 1_000_000))
        let resolver = ServerURLResolver(
            wifiMonitor: StubWiFi(),
            prober: prober,
            dateProvider: { mutableNow.now }
        )

        let config = makeConfig()

        // First call: cache miss → probes once
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 1)

        // Within 60s: cache hit, no additional probe
        mutableNow.advance(by: 30)
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 1)

        mutableNow.advance(by: 29) // total 59s; still inside TTL
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 1)

        // Past 60s: cache expired, reprobes
        mutableNow.advance(by: 2) // total 61s
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 2)
    }

    func testSSIDFastPathReturnsInternalURLWithoutProbing() async {
        let prober = StubProber(reachable: false)
        let wifi = StubWiFi(currentSSID: "HomeWiFi", isOnWiFi: true, hasLocationPermission: true)
        let resolver = ServerURLResolver(wifiMonitor: wifi, prober: prober, dateProvider: { Date() })

        let config = makeConfig()

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), internalURL)
        XCTAssertTrue(resolver.isUsingInternalURL(for: config))
        let resolved = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(resolved, internalURL)
        XCTAssertEqual(prober.callCount, 0, "A matching SSID must short-circuit the probe")
    }

    func testProbeAndResolveSkipsProbeWhenInternalNotConfigured() async {
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober, dateProvider: { Date() })

        let config = ServerConfiguration(
            name: "no-internal",
            jellyfinURL: externalURL
        )

        let resolved = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolved, externalURL)
        XCTAssertEqual(prober.callCount, 0)
    }

    func testSynchronousConsumersUseReachabilityResult() async {
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: StubProber(reachable: true))
        let config = makeConfig()

        _ = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), internalURL)
        XCTAssertTrue(resolver.isUsingInternalURL(for: config))
    }

    func testURLChangeDoesNotReuseProbeForOldHost() async throws {
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober)
        let config = makeConfig()
        _ = await resolver.probeAndResolve(for: config)
        config.internalJellyfinURL = try XCTUnwrap(URL(string: "http://192.168.1.20:8096"))

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
        _ = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(prober.callCount, 2)
    }

    func testNetworkChangeInvalidatesCachedInternalURL() async {
        let wifi = StubWiFi()
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: wifi, prober: prober)
        let config = makeConfig()
        _ = await resolver.probeAndResolve(for: config)

        wifi.networkRevision += 1

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 2)
    }

    func testUnreachableInternalURLIsUsedByNeitherConsumer() async {
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: StubProber(reachable: false))
        let config = makeConfig()

        let resolved = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolved, externalURL)
        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
        XCTAssertFalse(resolver.isUsingInternalURL(for: config))
    }

    func testConfigurationChangeDuringProbeDiscardsResult() async throws {
        let prober = SuspendedProber()
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober)
        let config = makeConfig()
        let resolution = Task { await resolver.probeAndResolve(for: config) }
        await prober.waitUntilStarted()
        config.internalJellyfinURL = try XCTUnwrap(URL(string: "http://192.168.1.20:8096"))

        await prober.complete()
        let resolved = await resolution.value

        XCTAssertEqual(resolved, externalURL)
        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
    }

    func testNetworkChangeDuringProbeDiscardsResult() async {
        let wifi = StubWiFi()
        let prober = SuspendedProber()
        let resolver = ServerURLResolver(wifiMonitor: wifi, prober: prober)
        let config = makeConfig()
        let resolution = Task { await resolver.probeAndResolve(for: config) }
        await prober.waitUntilStarted()
        wifi.networkRevision += 1

        await prober.complete()
        let resolved = await resolution.value

        XCTAssertEqual(resolved, externalURL)
        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
    }

    func testExternalURLChangeInvalidatesCachedProbe() async throws {
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: prober)
        let config = makeConfig()
        _ = await resolver.probeAndResolve(for: config)
        let updatedExternalURL = try XCTUnwrap(URL(string: "https://new.example.com"))
        config.jellyfinURL = updatedExternalURL

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), updatedExternalURL)
        _ = await resolver.probeAndResolve(for: config)
        XCTAssertEqual(prober.callCount, 2)
    }

    func testSynchronousConsumersKeepResolvedAddressUntilNextProbe() async {
        let now = MutableNow(initial: Date())
        let resolver = ServerURLResolver(
            wifiMonitor: StubWiFi(),
            prober: StubProber(reachable: true),
            dateProvider: { now.now }
        )
        let config = makeConfig()
        _ = await resolver.probeAndResolve(for: config)
        now.advance(by: 61)

        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), internalURL)
    }

    func testNetworkRefreshPreservesClientConfigurationIdentity() {
        let wifi = StubWiFi()
        let resolver = ServerURLResolver(wifiMonitor: wifi, prober: StubProber(reachable: true))
        let config = makeConfig()
        let original = resolver.context(for: config)
        wifi.networkRevision += 1
        let refreshed = resolver.context(for: config)

        XCTAssertNotEqual(original, refreshed)
        XCTAssertTrue(original.matchesConfiguration(of: refreshed))
    }

    func testURLChangesInvalidateClientConfigurationIdentity() throws {
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: StubProber(reachable: true))
        let config = makeConfig()
        let original = resolver.context(for: config)
        config.internalJellyfinURL = try XCTUnwrap(URL(string: "http://192.168.1.20:8096"))

        XCTAssertFalse(original.matchesConfiguration(of: resolver.context(for: config)))
    }

    func testServerChangesInvalidateClientConfigurationIdentity() {
        let resolver = ServerURLResolver(wifiMonitor: StubWiFi(), prober: StubProber(reachable: true))
        let original = resolver.context(for: makeConfig())

        XCTAssertFalse(original.matchesConfiguration(of: resolver.context(for: makeConfig())))
    }

    func testKnownDifferentNetworkUsesExternalWithoutProbing() async {
        let wifi = StubWiFi(currentSSID: "CoffeeShop", isOnWiFi: true, hasLocationPermission: true)
        let prober = StubProber(reachable: true)
        let resolver = ServerURLResolver(wifiMonitor: wifi, prober: prober)
        let config = makeConfig()

        let resolved = await resolver.probeAndResolve(for: config)

        XCTAssertEqual(resolved, externalURL)
        XCTAssertEqual(resolver.resolveJellyfinURL(for: config), externalURL)
        XCTAssertEqual(prober.callCount, 0)
    }

    // MARK: - Helpers

    private func makeConfig() -> ServerConfiguration {
        ServerConfiguration(
            name: "test",
            jellyfinURL: externalURL,
            internalJellyfinURL: internalURL,
            internalNetworkSSIDs: ["HomeWiFi"]
        )
    }
}

// MARK: - Stubs

/// Deterministic Wi-Fi state. Keeps the resolver tests away from
/// `WiFiSSIDMonitor.shared`, whose CoreLocation setup is not usable in a
/// host-less test process.
@MainActor
final class StubWiFi: WiFiNetworkStatus {
    var networkRevision: UInt64 = 0
    var currentSSID: String?
    var isOnWiFi: Bool
    var hasLocationPermission: Bool

    init(currentSSID: String? = nil, isOnWiFi: Bool = false, hasLocationPermission: Bool = false) {
        self.currentSSID = currentSSID
        self.isOnWiFi = isOnWiFi
        self.hasLocationPermission = hasLocationPermission
    }

    func requestLocationPermission() {}
    func refresh() {}
}

final class StubProber: ReachabilityProber {
    private struct State {
        var callCount = 0
    }

    private let mutableState = OSAllocatedUnfairLock(initialState: State())
    private let reachable: Bool

    init(reachable: Bool) {
        self.reachable = reachable
    }

    var callCount: Int {
        mutableState.withLock { $0.callCount }
    }

    func probe(url _: URL) async -> Bool {
        mutableState.withLock { $0.callCount += 1 }
        return reachable
    }
}

@MainActor
final class MutableNow {
    private(set) var now: Date

    init(initial: Date) {
        now = initial
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private actor SuspendedProber: ReachabilityProber {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func probe(url _: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if continuation != nil {
            return
        }
        await withCheckedContinuation { started = $0 }
    }

    func complete() {
        continuation?.resume(returning: true)
        continuation = nil
    }
}
