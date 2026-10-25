import Combine
import Foundation

/// Probes whether a candidate server URL is currently reachable. Production
/// uses `URLSession` with a 1s timeout; tests substitute a deterministic stub.
public protocol ReachabilityProber: Sendable {
    func probe(url: URL) async -> Bool
}

private final class ProbeRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public struct URLSessionReachabilityProber: ReachabilityProber {
    public init() {}

    public func probe(url: URL) async -> Bool {
        let endpoint = url.appendingPathComponent("System/Info/Public")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 1
        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.urlCache = nil
            configuration.timeoutIntervalForResource = 1
            let session = URLSession(
                configuration: configuration,
                delegate: ProbeRedirectDelegate(),
                delegateQueue: nil
            )
            defer { session.invalidateAndCancel() }
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ... 299).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

/// Resolves configured Jellyfin addresses using SSID or credential-free reachability.
@MainActor
public final class ServerURLResolver: ObservableObject {
    /// Singleton instance
    public static let shared = ServerURLResolver()

    private let wifiMonitor: any WiFiNetworkStatus
    private let prober: any ReachabilityProber
    private let dateProvider: @MainActor @Sendable () -> Date
    private var probeCache: [UUID: CachedProbe] = [:]

    public struct Context: Hashable, Sendable {
        let serverID: UUID
        let externalURL: URL
        let internalURL: URL?
        let ssids: [String]
        let currentSSID: String?
        let isOnWiFi: Bool
        let networkRevision: UInt64
    }

    /// Identifies the configured destinations and network used by a resolution.
    public func context(for config: ServerConfiguration) -> Context {
        Context(
            serverID: config.id,
            externalURL: config.jellyfinURL,
            internalURL: config.internalJellyfinURL,
            ssids: config.internalNetworkSSIDs,
            currentSSID: wifiMonitor.currentSSID,
            isOnWiFi: wifiMonitor.isOnWiFi,
            networkRevision: wifiMonitor.networkRevision
        )
    }

    private struct CachedProbe {
        let context: Context
        let reachable: Bool
        let timestamp: Date
    }

    private static let cacheTTL: TimeInterval = 60

    public init(
        wifiMonitor: any WiFiNetworkStatus = WiFiSSIDMonitor.shared,
        prober: any ReachabilityProber = URLSessionReachabilityProber(),
        dateProvider: @MainActor @Sendable @escaping () -> Date = { Date() }
    ) {
        self.wifiMonitor = wifiMonitor
        self.prober = prober
        self.dateProvider = dateProvider
    }

    /// Returns the SSID choice or last probe result for the current configuration and network.
    /// Async callers must resolve before constructing clients when SSID is unavailable.
    public func resolveJellyfinURL(for config: ServerConfiguration) -> URL {
        guard config.hasInternalURL, let internalURL = config.internalJellyfinURL else {
            return config.jellyfinURL
        }
        if let ssid = wifiMonitor.currentSSID, config.internalNetworkSSIDs.contains(ssid) {
            return internalURL
        }
        if let cached = validProbe(for: config, requireFresh: false), cached.reachable {
            return internalURL
        }
        return config.jellyfinURL
    }

    private func validProbe(for config: ServerConfiguration, requireFresh: Bool = true) -> CachedProbe? {
        guard let cached = probeCache[config.id],
              cached.context == context(for: config),
              !requireFresh || dateProvider().timeIntervalSince(cached.timestamp) < Self.cacheTTL
        else { return nil }
        return cached
    }

    /// Probes when SSID does not match. Results expire after 60 seconds and are
    /// discarded when configured destinations or network state change during the probe.
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

        if let cached = validProbe(for: config) {
            return cached.reachable ? internalURL : config.jellyfinURL
        }

        let initialContext = context(for: config)
        let reachable = await prober.probe(url: internalURL)
        guard !Task.isCancelled, initialContext == context(for: config) else {
            return config.jellyfinURL
        }
        probeCache[config.id] = CachedProbe(
            context: initialContext,
            reachable: reachable,
            timestamp: dateProvider()
        )
        return reachable ? internalURL : config.jellyfinURL
    }

    /// Check if currently using internal URL for a server
    public func isUsingInternalURL(for config: ServerConfiguration) -> Bool {
        config.hasInternalURL && resolveJellyfinURL(for: config) == config.internalJellyfinURL
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
