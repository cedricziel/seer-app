import CoreLocation
import Foundation
import Network
#if os(iOS)
    import SystemConfiguration.CaptiveNetwork
#elseif os(macOS)
    import CoreWLAN
#endif

/// Monitors the current WiFi network SSID
@MainActor
public final class WiFiSSIDMonitor: ObservableObject, WiFiNetworkStatus {
    /// The current WiFi SSID (nil if not on WiFi or permission denied)
    @Published public private(set) var currentSSID: String?

    /// Whether we're currently connected to WiFi
    @Published public private(set) var isOnWiFi: Bool = false

    /// Whether location permission is granted (needed for SSID access)
    @Published public private(set) var hasLocationPermission: Bool = false

    @Published public private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    @Published public private(set) var networkRevision: UInt64 = 0

    private let pathMonitor = NWPathMonitor()
    private let locationManager = CLLocationManager()
    private var locationDelegate: LocationDelegate?

    public static let shared = WiFiSSIDMonitor()

    private init() {
        locationDelegate = LocationDelegate { [weak self] status in
            Task { @MainActor [weak self] in
                self?.locationAuthorizationStatus = status
                #if os(macOS)
                    self?.hasLocationPermission = status == .authorizedAlways
                #else
                    self?.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
                #endif
                self?.updateSSID()
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

    /// Requests location permission where the platform supports Wi-Fi SSID access.
    public func requestLocationPermission() {
        #if os(iOS)
            locationManager.requestAlwaysAuthorization()
        #elseif os(macOS)
            locationManager.requestWhenInUseAuthorization()
        #endif
    }

    /// Manually refresh the current SSID
    public func refresh() {
        networkRevision &+= 1
        updateSSID()
    }

    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.networkRevision &+= 1
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
        #if os(iOS)
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
        #elseif os(macOS)
            return CWWiFiClient.shared().interface()?.ssid()
        #else
            return nil
        #endif
    }

    deinit {
        pathMonitor.cancel()
    }
}

// MARK: - Location Delegate

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onAuthorizationChanged: (CLAuthorizationStatus) -> Void

    init(onAuthorizationChanged: @escaping (CLAuthorizationStatus) -> Void) {
        self.onAuthorizationChanged = onAuthorizationChanged
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        onAuthorizationChanged(status)
    }
}
