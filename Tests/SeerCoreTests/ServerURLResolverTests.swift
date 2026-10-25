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
