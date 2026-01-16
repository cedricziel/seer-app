import Foundation

/// Resolves the appropriate server URL based on the current network context
@MainActor
public final class ServerURLResolver: ObservableObject {
    /// Singleton instance
    public static let shared = ServerURLResolver()

    private let wifiMonitor: WiFiSSIDMonitor

    private init(wifiMonitor: WiFiSSIDMonitor = .shared) {
        self.wifiMonitor = wifiMonitor
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
