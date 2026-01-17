import ErrataSDK
import MetricKit
import OSLog

/// MetricKit subscriber that collects and logs performance metrics and diagnostic payloads.
/// MetricKit delivers daily metric reports (on App Store/TestFlight builds) with information about:
/// - CPU usage, memory, disk I/O
/// - Launch time, hang rate, responsiveness
/// - Crash reports and diagnostic payloads
///
/// **Privacy**: This reporter respects user consent via `DiagnosticsConsent`.
/// Data is only processed/sent when the user has explicitly opted in.
/// When consent is granted, data is sent to Errata for analysis.
@MainActor
public final class MetricsReporter: NSObject, MXMetricManagerSubscriber {
    /// Shared instance of the metrics reporter
    public static let shared = MetricsReporter()

    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "MetricsReporter")

    /// Errata DSN for error reporting (loaded from Info.plist)
    private static var errataDSN: String? {
        Bundle.main.object(forInfoDictionaryKey: "ErrataDSN") as? String
    }

    /// Whether Errata has been initialized
    private var isErrataInitialized = false

    override private init() {
        super.init()
        MXMetricManager.shared.add(self)
        Self.logger.info("MetricsReporter initialized and subscribed to MetricKit")

        // Initialize Errata if consent is already granted
        initializeErrataIfConsented()
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - Errata Initialization

    /// Initialize Errata SDK if user has consented to diagnostics
    public func initializeErrataIfConsented() {
        guard !isErrataInitialized else { return }

        let consent = DiagnosticsConsent.shared
        guard consent.crashReportsEnabled || consent.performanceMetricsEnabled else {
            Self.logger.debug("Errata not initialized - no consent granted")
            return
        }

        guard let dsn = Self.errataDSN, !dsn.isEmpty, !dsn.contains("$(") else {
            Self.logger.warning("Errata not initialized - DSN not configured in Info.plist")
            return
        }

        let config = Configuration(
            dsn: dsn,
            environment: "production",
            enableCrashReporting: consent.crashReportsEnabled,
            enableExceptionCapture: consent.crashReportsEnabled,
            maxBreadcrumbs: 50,
            debug: false
        )

        Errata.shared.start(with: config)
        isErrataInitialized = true

        // Set app context
        Errata.shared.setTag("app.version", value: Bundle.main.appVersion)
        Errata.shared.setTag("app.build", value: Bundle.main.buildNumber)

        Self.logger.info("Errata SDK initialized with consent")
    }

    /// Call this when consent changes to initialize or update Errata
    public func onConsentChanged() {
        let consent = DiagnosticsConsent.shared

        if consent.crashReportsEnabled || consent.performanceMetricsEnabled {
            if !isErrataInitialized {
                initializeErrataIfConsented()
            }
        }
        // Note: Errata doesn't support runtime disable, so we just stop sending new events
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called when MetricKit delivers daily metric payloads containing performance data.
    /// These payloads include CPU, memory, disk I/O, launch time, and responsiveness metrics.
    ///
    /// **Privacy**: Only processes data if user has consented to performance metrics collection.
    public nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        guard !payloads.isEmpty else { return }

        // Copy count before crossing isolation boundary
        let count = payloads.count
        // MXMetricPayload is not Sendable, so extract JSON data on the current thread
        let jsonDataList = payloads.map { $0.jsonRepresentation() }

        Task { @MainActor in
            // Check consent before processing
            guard DiagnosticsConsent.shared.performanceMetricsEnabled else {
                Self.logger.debug(
                    "Received \(count) metric payload(s) but performance metrics consent not granted - discarding"
                )
                return
            }

            Self.logger.info("Received \(count) metric payload(s)")

            for jsonData in jsonDataList {
                // Send to Errata as a custom event
                if isErrataInitialized {
                    Errata.shared.addBreadcrumb(
                        category: "metrics",
                        message: "MetricKit payload received",
                        level: .info,
                        data: ["payloadSize": jsonData.count]
                    )

                    // Record key metrics
                    if let metrics = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        recordMetricsToErrata(metrics)
                    }
                }

                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    Self.logger.debug("Metric payload JSON: \(jsonString)")
                }
            }
        }
    }

    /// Called when MetricKit delivers diagnostic payloads containing crash reports,
    /// hang reports, disk write exceptions, and CPU exceptions.
    ///
    /// **Privacy**: Only processes data if user has consented to crash reports collection.
    public nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }

        // Copy count before crossing isolation boundary
        let count = payloads.count
        // MXDiagnosticPayload is not Sendable, so extract JSON data on the current thread
        let jsonDataList = payloads.map { $0.jsonRepresentation() }

        Task { @MainActor in
            // Check consent before processing
            guard DiagnosticsConsent.shared.crashReportsEnabled else {
                Self.logger.debug(
                    "Received \(count) diagnostic payload(s) but crash reports consent not granted - discarding"
                )
                return
            }

            Self.logger.warning("Received \(count) diagnostic payload(s)")

            for jsonData in jsonDataList {
                // Send to Errata
                if isErrataInitialized {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        Errata.shared.captureMessage(
                            "MetricKit Diagnostic Report",
                            level: .error,
                            context: ["payload": jsonString]
                        )
                    }
                }

                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    Self.logger.warning("Diagnostic payload JSON: \(jsonString)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func recordMetricsToErrata(_ metrics: [String: Any]) {
        // Extract and record key performance metrics
        if let appLaunch = metrics["applicationLaunchMetrics"] as? [String: Any],
           let timeToFirstDraw = appLaunch["histogrammedTimeToFirstDraw"] as? [String: Any],
           let avg = timeToFirstDraw["averageValue"] as? Double {
            Errata.shared.recordMetric(name: "app.launch.time_to_first_draw", value: avg, unit: "ms")
        }

        if let memoryMetrics = metrics["memoryMetrics"] as? [String: Any],
           let peakMemory = memoryMetrics["peakMemoryUsage"] as? Double {
            Errata.shared.recordMetric(name: "app.memory.peak_usage", value: peakMemory, unit: "bytes")
        }

        if let cpuMetrics = metrics["cpuMetrics"] as? [String: Any],
           let cumulativeCPU = cpuMetrics["cumulativeCPUTime"] as? Double {
            Errata.shared.recordMetric(name: "app.cpu.cumulative_time", value: cumulativeCPU, unit: "ms")
        }
    }
}

// MARK: - Bundle Extensions

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
