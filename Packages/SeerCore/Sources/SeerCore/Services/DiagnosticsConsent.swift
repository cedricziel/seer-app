import Foundation
import OSLog

/// Stores device-local diagnostics preferences. Missing preferences default to enabled.
@MainActor
public final class DiagnosticsConsent: ObservableObject {
    public static let shared = DiagnosticsConsent()

    private let preferences: DiagnosticsPreferences

    @Published public var crashReportsEnabled: Bool {
        didSet {
            preferences.crashReportsEnabled = crashReportsEnabled
            TelemetryService.shared.onConsentChanged()
        }
    }

    @Published public var performanceMetricsEnabled: Bool {
        didSet {
            preferences.performanceMetricsEnabled = performanceMetricsEnabled
            TelemetryService.shared.onConsentChanged()
        }
    }

    public var isAnyDiagnosticsEnabled: Bool {
        crashReportsEnabled || performanceMetricsEnabled
    }

    private init() {
        preferences = .shared
        crashReportsEnabled = preferences.crashReportsEnabled
        performanceMetricsEnabled = preferences.performanceMetricsEnabled
    }
}

public extension DiagnosticsConsent {
    /// Summary of collected data types for privacy documentation
    struct DataCollectionSummary: Sendable {
        public let dataType: String
        public let purpose: String
        public let linkedToIdentity: Bool
        public let usedForTracking: Bool

        public static let crashReports = DataCollectionSummary(
            dataType: "Crash Data",
            purpose: "App Functionality",
            linkedToIdentity: true,
            usedForTracking: false
        )

        public static let performanceMetrics = DataCollectionSummary(
            dataType: "Performance Data",
            purpose: "App Functionality",
            linkedToIdentity: true,
            usedForTracking: false
        )

        public static let deviceInfo = DataCollectionSummary(
            dataType: "Device ID",
            purpose: "App Functionality",
            linkedToIdentity: true,
            usedForTracking: false
        )
    }

    /// All data types collected when diagnostics are enabled
    static let collectedDataTypes: [DataCollectionSummary] = [
        .crashReports,
        .performanceMetrics,
        .deviceInfo
    ]
}
