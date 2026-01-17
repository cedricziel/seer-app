import MetricKit
import OSLog

/// MetricKit subscriber that collects and logs performance metrics and diagnostic payloads.
/// MetricKit delivers daily metric reports (on App Store/TestFlight builds) with information about:
/// - CPU usage, memory, disk I/O
/// - Launch time, hang rate, responsiveness
/// - Crash reports and diagnostic payloads
///
/// **Privacy**: This reporter respects user consent via `DiagnosticsConsent`.
/// Data is only processed/logged when the user has explicitly opted in.
@MainActor
public final class MetricsReporter: NSObject, MXMetricManagerSubscriber {
    /// Shared instance of the metrics reporter
    public static let shared = MetricsReporter()

    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "MetricsReporter")

    /// Reference to consent manager
    private let consent = DiagnosticsConsent.shared

    override private init() {
        super.init()
        MXMetricManager.shared.add(self)
        Self.logger.info("MetricsReporter initialized and subscribed to MetricKit")
    }

    deinit {
        MXMetricManager.shared.remove(self)
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
                Self.logger
                    .debug(
                        "Received \(count) metric payload(s) but performance metrics consent not granted - discarding"
                    )
                return
            }

            Self.logger.info("Received \(count) metric payload(s)")

            for jsonData in jsonDataList {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    Self.logger.debug("Metric payload JSON: \(jsonString)")
                    // Future: Send to backend if user consented
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
                Self.logger
                    .debug("Received \(count) diagnostic payload(s) but crash reports consent not granted - discarding")
                return
            }

            Self.logger.warning("Received \(count) diagnostic payload(s)")

            for jsonData in jsonDataList {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    Self.logger.warning("Diagnostic payload JSON: \(jsonString)")
                    // Future: Send to backend if user consented
                }
            }
        }
    }
}
