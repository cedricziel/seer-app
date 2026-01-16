import CoreLocation
import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

/// Monitors the current WiFi network SSID
@MainActor
public final class WiFiSSIDMonitor: ObservableObject {
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
        locationManager.delegate = locationDelegate

        setupNetworkMonitoring()
        checkLocationPermission()
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

    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
        if hasLocationPermission {
            updateSSID()
        }
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
