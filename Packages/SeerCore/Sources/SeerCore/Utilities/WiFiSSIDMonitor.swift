import CoreLocation
import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

/// Read-only view of the current Wi-Fi network state. `WiFiSSIDMonitor` is
/// the production implementation; tests substitute a stub so resolver logic
/// never touches CoreLocation.
@MainActor
public protocol WiFiNetworkStatus: AnyObject {
    var currentSSID: String? { get }
    var isOnWiFi: Bool { get }
    var hasLocationPermission: Bool { get }
    func requestLocationPermission()
    func refresh()
}

/// Monitors the current WiFi network SSID
@MainActor
public final class WiFiSSIDMonitor: ObservableObject, WiFiNetworkStatus {
    /// The current WiFi SSID (nil if not on WiFi or permission denied)
    @Published public private(set) var currentSSID: String?

    /// Whether we're currently connected to WiFi
    @Published public private(set) var isOnWiFi: Bool = false

    /// Whether location permission is granted (needed for SSID access)
    @Published public private(set) var hasLocationPermission: Bool = false

    private let pathMonitor = NWPathMonitor()
    private let locationManager = CLLocationManager()
    private var locationDelegate: LocationDelegate?

    public static let shared = WiFiSSIDMonitor()

    private init() {
        locationDelegate = LocationDelegate { [weak self] authorized in
            Task { @MainActor [weak self] in
                self?.hasLocationPermission = authorized
                if authorized {
                    self?.updateSSID()
                }
            }
        }
        // CoreLocation invokes `locationManagerDidChangeAuthorization` as soon
        // as the delegate is set, so the initial permission state arrives
        // through the delegate. Do NOT read `authorizationStatus` here: that
        // call blocks the calling thread on an XPC round trip to locationd,
        // and in a host-less test process on the simulator it never returns.
        locationManager.delegate = locationDelegate

        setupNetworkMonitoring()
    }

    /// Request location permission (required to read WiFi SSID)
    /// Requests "Always" authorization to enable background network detection
    public func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Manually refresh the current SSID
    public func refresh() {
        updateSSID()
    }

    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let onWiFi = path.usesInterfaceType(.wifi)
                self?.isOnWiFi = onWiFi
                if onWiFi {
                    self?.updateSSID()
                } else {
                    self?.currentSSID = nil
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func updateSSID() {
        guard hasLocationPermission else {
            currentSSID = nil
            return
        }

        #if targetEnvironment(simulator)
            // Simulator doesn't support WiFi SSID - use a test value
            currentSSID = "Simulator-WiFi"
        #else
            currentSSID = fetchCurrentSSID()
        #endif
    }

    private func fetchCurrentSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }

        for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary?,
               let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }

        return nil
    }

    deinit {
        pathMonitor.cancel()
    }
}

// MARK: - Location Delegate

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onAuthorizationChanged: (Bool) -> Void

    init(onAuthorizationChanged: @escaping (Bool) -> Void) {
        self.onAuthorizationChanged = onAuthorizationChanged
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        onAuthorizationChanged(authorized)
    }
}
