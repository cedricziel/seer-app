import Foundation
import OSLog

/// Manages user consent for diagnostic data collection and sharing.
/// Respects user privacy by requiring explicit opt-in for crash reports and performance metrics.
@MainActor
public final class DiagnosticsConsent: ObservableObject {
    /// Shared instance
    public static let shared = DiagnosticsConsent()

    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "DiagnosticsConsent")

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let hasShownConsentPrompt = "diagnostics.hasShownConsentPrompt"
        static let crashReportsEnabled = "diagnostics.crashReportsEnabled"
        static let performanceMetricsEnabled = "diagnostics.performanceMetricsEnabled"
        static let consentTimestamp = "diagnostics.consentTimestamp"
        static let consentVersion = "diagnostics.consentVersion"
    }

    /// Current consent policy version. Increment when privacy policy changes significantly.
    public static let currentConsentVersion = 1

    // MARK: - Published Properties

    /// Whether the user has been shown the consent prompt
    @Published public private(set) var hasShownConsentPrompt: Bool {
        didSet {
            UserDefaults.standard.set(hasShownConsentPrompt, forKey: Keys.hasShownConsentPrompt)
        }
    }

    /// Whether crash report sharing is enabled
    @Published public var crashReportsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(crashReportsEnabled, forKey: Keys.crashReportsEnabled)
            logConsentChange("Crash reports", enabled: crashReportsEnabled)
            notifyConsentChanged()
        }
    }

    /// Whether performance metrics sharing is enabled
    @Published public var performanceMetricsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(performanceMetricsEnabled, forKey: Keys.performanceMetricsEnabled)
            logConsentChange("Performance metrics", enabled: performanceMetricsEnabled)
            notifyConsentChanged()
        }
    }

    // MARK: - Computed Properties

    /// Whether any diagnostic sharing is enabled
    public var isAnyDiagnosticsEnabled: Bool {
        crashReportsEnabled || performanceMetricsEnabled
    }

    /// Whether we need to show the consent prompt (first launch or policy version changed)
    public var needsConsentPrompt: Bool {
        !hasShownConsentPrompt || consentVersion < Self.currentConsentVersion
    }

    /// The version of the consent policy the user agreed to
    public var consentVersion: Int {
        UserDefaults.standard.integer(forKey: Keys.consentVersion)
    }

    /// When the user last updated their consent
    public var consentTimestamp: Date? {
        UserDefaults.standard.object(forKey: Keys.consentTimestamp) as? Date
    }

    // MARK: - Initialization

    private init() {
        hasShownConsentPrompt = UserDefaults.standard.bool(forKey: Keys.hasShownConsentPrompt)
        crashReportsEnabled = UserDefaults.standard.bool(forKey: Keys.crashReportsEnabled)
        performanceMetricsEnabled = UserDefaults.standard.bool(forKey: Keys.performanceMetricsEnabled)

        let crashes = crashReportsEnabled
        let performance = performanceMetricsEnabled
        Self.logger.debug("DiagnosticsConsent initialized - crashes: \(crashes), performance: \(performance)")
    }

    // MARK: - Public Methods

    /// Record that the consent prompt was shown and user made a choice
    public func recordConsentShown() {
        hasShownConsentPrompt = true
        UserDefaults.standard.set(Date(), forKey: Keys.consentTimestamp)
        UserDefaults.standard.set(Self.currentConsentVersion, forKey: Keys.consentVersion)
        Self.logger.info("Consent prompt shown and recorded at version \(Self.currentConsentVersion)")
    }

    /// Enable all diagnostics (user opted in to everything)
    public func enableAllDiagnostics() {
        crashReportsEnabled = true
        performanceMetricsEnabled = true
        recordConsentShown()
        Self.logger.info("User enabled all diagnostics")
    }

    /// Disable all diagnostics (user opted out of everything)
    public func disableAllDiagnostics() {
        crashReportsEnabled = false
        performanceMetricsEnabled = false
        recordConsentShown()
        Self.logger.info("User disabled all diagnostics")
    }

    /// Reset consent state (for testing or when user requests data deletion)
    public func resetConsent() {
        hasShownConsentPrompt = false
        crashReportsEnabled = false
        performanceMetricsEnabled = false
        UserDefaults.standard.removeObject(forKey: Keys.consentTimestamp)
        UserDefaults.standard.removeObject(forKey: Keys.consentVersion)
        Self.logger.info("Consent state reset")
    }

    // MARK: - Private Methods

    private func logConsentChange(_ feature: String, enabled: Bool) {
        Self.logger.info("\(feature) consent changed to: \(enabled)")
    }

    private func notifyConsentChanged() {
        // Notify TelemetryService to initialize/update OpenTelemetry SDK
        TelemetryService.shared.onConsentChanged()
    }
}

// MARK: - Consent Summary for Privacy Nutrition Label

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
            linkedToIdentity: false,
            usedForTracking: false
        )

        public static let performanceMetrics = DataCollectionSummary(
            dataType: "Performance Data",
            purpose: "App Functionality",
            linkedToIdentity: false,
            usedForTracking: false
        )

        public static let deviceInfo = DataCollectionSummary(
            dataType: "Device ID",
            purpose: "App Functionality",
            linkedToIdentity: false,
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
