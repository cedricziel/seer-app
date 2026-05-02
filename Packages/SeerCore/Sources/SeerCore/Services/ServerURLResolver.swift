import Foundation

/// Probes whether a candidate server URL is currently reachable. Production
/// uses `URLSession` with a 1s timeout; tests substitute a deterministic stub.
public protocol ReachabilityProber: Sendable {
    func probe(url: URL) async -> Bool
}

public struct URLSessionReachabilityProber: ReachabilityProber {
    public init() {}

    public func probe(url: URL) async -> Bool {
        let endpoint = url.appendingPathComponent("System/Info/Public")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 1
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ... 499).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

/// Resolves the appropriate server URL based on the current network context.
///
/// Two paths:
/// - **SSID fast path** (sync `resolveJellyfinURL`): if `currentSSID` is in
///   `internalNetworkSSIDs`, return the internal URL.
/// - **Reachability fallback** (async `probeAndResolve`): when SSID is
///   unknown (location permission denied, on cellular, etc.), probe the
///   internal URL with a 1s timeout and cache the result for 60s.
@MainActor
public final class ServerURLResolver: ObservableObject {
    /// Singleton instance
    public static let shared = ServerURLResolver()

    private let wifiMonitor: WiFiSSIDMonitor
    private let prober: any ReachabilityProber
    private let dateProvider: @MainActor @Sendable () -> Date
    private var probeCache: [UUID: CachedProbe] = [:]

    private struct CachedProbe {
        let reachable: Bool
        let timestamp: Date
    }

    private static let cacheTTL: TimeInterval = 60

    public init(
        wifiMonitor: WiFiSSIDMonitor = .shared,
        prober: any ReachabilityProber = URLSessionReachabilityProber(),
        dateProvider: @MainActor @Sendable @escaping () -> Date = { Date() }
    ) {
        self.wifiMonitor = wifiMonitor
        self.prober = prober
        self.dateProvider = dateProvider
    }

    /// Resolve the Jellyfin URL for a server configuration
    /// Returns internal URL if on a configured internal network, otherwise external URL
    public func resolveJellyfinURL(for config: ServerConfiguration) -> URL {
        guard config.hasInternalURL,
              let internalURL = config.internalJellyfinURL,
              let currentSSID = wifiMonitor.currentSSID
        else {
            return config.jellyfinURL
        }

        // Check if current SSID matches any configured internal networks
        if config.internalNetworkSSIDs.contains(currentSSID) {
            return internalURL
        }

        return config.jellyfinURL
    }

    /// Async resolution that consults the reachability probe when the SSID
    /// fast path doesn't apply. Probe results are cached for 60 seconds per
    /// server configuration.
    public func probeAndResolve(for config: ServerConfiguration) async -> URL {
        guard config.hasInternalURL,
              let internalURL = config.internalJellyfinURL
        else {
            return config.jellyfinURL
        }

        // SSID fast path
        if let currentSSID = wifiMonitor.currentSSID,
           config.internalNetworkSSIDs.contains(currentSSID) {
            return internalURL
        }

        // Cache hit?
        let now = dateProvider()
        if let cached = probeCache[config.id],
           now.timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.reachable ? internalURL : config.jellyfinURL
        }

        // Probe + cache
        let reachable = await prober.probe(url: internalURL)
        probeCache[config.id] = CachedProbe(reachable: reachable, timestamp: now)
        return reachable ? internalURL : config.jellyfinURL
    }

    /// Check if currently using internal URL for a server
    public func isUsingInternalURL(for config: ServerConfiguration) -> Bool {
        guard config.hasInternalURL,
              let currentSSID = wifiMonitor.currentSSID
        else {
            return false
        }

        return config.internalNetworkSSIDs.contains(currentSSID)
    }

    /// Get the current WiFi SSID (if available)
    public var currentSSID: String? {
        wifiMonitor.currentSSID
    }

    /// Whether we're on WiFi
    public var isOnWiFi: Bool {
        wifiMonitor.isOnWiFi
    }

    /// Whether location permission is granted
    public var hasLocationPermission: Bool {
        wifiMonitor.hasLocationPermission
    }

    /// Request location permission for SSID access
    public func requestLocationPermission() {
        wifiMonitor.requestLocationPermission()
    }

    /// Refresh network status
    public func refresh() {
        wifiMonitor.refresh()
    }
}
