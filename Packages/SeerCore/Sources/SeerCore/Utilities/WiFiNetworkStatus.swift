import Foundation

/// Read-only view of the current Wi-Fi network state. `WiFiSSIDMonitor` is
/// the production implementation; tests substitute a stub so resolver logic
/// never touches CoreLocation.
@MainActor
public protocol WiFiNetworkStatus: AnyObject {
    var currentSSID: String? { get }
    var networkRevision: UInt64 { get }
    var isOnWiFi: Bool { get }
    var hasLocationPermission: Bool { get }
    func requestLocationPermission()
    func refresh()
}

public extension WiFiNetworkStatus {
    var networkRevision: UInt64 {
        0
    }
}
