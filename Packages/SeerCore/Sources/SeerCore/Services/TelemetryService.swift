import Foundation
import Logging
import MetricKit
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import OSLog
import OTelSwiftLog
import PersistenceExporter
import ResourceExtension
import SignPostIntegration

/// OpenTelemetry-based telemetry service that collects and reports performance metrics and crash data.
/// This service replaces the previous Errata SDK implementation while preserving the same consent model.
///
/// **Privacy**: This service respects user consent via `DiagnosticsConsent`.
/// Data is only processed/sent when the user has explicitly opted in.
@MainActor
public final class TelemetryService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    /// Shared instance of the telemetry service
    public static let shared = TelemetryService()

    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "TelemetryService")

    /// OTLP endpoint for telemetry (loaded from Info.plist)
    private static var otlpEndpoint: String? {
        Bundle.main.object(forInfoDictionaryKey: "OTLPEndpoint") as? String
    }

    /// OTLP auth header (loaded from Info.plist, format: "HeaderName: HeaderValue")
    private static var otlpAuthHeader: (String, String)? {
        guard let headerString = Bundle.main.object(forInfoDictionaryKey: "OTLPAuthHeader") as? String,
              !headerString.isEmpty,
              !headerString.contains("$(") else {
            return nil
        }
        // Parse "HeaderName: HeaderValue" format
        let parts = headerString.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
        return (name, value)
    }

    /// Whether OTEL has been initialized
    private var isInitialized = false

    /// OpenTelemetry tracer for creating spans
    private var tracer: (any Tracer)?

    /// OpenTelemetry stable meter for recording metrics
    private var stableMeter: (any StableMeterProvider)?

    /// OpenTelemetry logger for crash reports
    private var otelLogger: (any OpenTelemetryApi.Logger)?

    /// Storage URL for persisting telemetry data when offline
    private static var persistenceStorageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("otel_telemetry", isDirectory: true)
    }

    override private init() {
        super.init()
        MXMetricManager.shared.add(self)
        Self.logger.info("TelemetryService initialized and subscribed to MetricKit")

        // Initialize OTEL if consent is already granted
        initializeIfConsented()
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - OTEL Initialization

    /// Initialize OpenTelemetry SDK if user has consented to diagnostics
    public func initializeIfConsented() {
        guard !isInitialized else { return }

        let consent = DiagnosticsConsent.shared
        guard consent.crashReportsEnabled || consent.performanceMetricsEnabled else {
            Self.logger.debug("OTEL not initialized - no consent granted")
            return
        }

        guard let endpoint = Self.otlpEndpoint, !endpoint.isEmpty, !endpoint.contains("$(") else {
            Self.logger.warning("OTEL not initialized - endpoint not configured in Info.plist")
            return
        }

        setupOTEL(endpoint: endpoint)

        // Initialize crash reporting if consented
        if consent.crashReportsEnabled, let otelLogger {
            CrashReportBridge.shared.initialize(logger: otelLogger)
        }

        isInitialized = true
        Self.logger.info("OpenTelemetry SDK initialized with consent")
    }

    private func setupOTEL(endpoint: String) {
        let resource = buildResource()
        let otlpConfig = buildOtlpConfig()

        guard let tracerProvider = setupTracerProvider(resource: resource, config: otlpConfig, endpoint: endpoint),
              let meterProvider = setupMeterProvider(resource: resource, config: otlpConfig, endpoint: endpoint),
              let logProvider = setupLoggerProvider(resource: resource, config: otlpConfig, endpoint: endpoint) else {
            return
        }

        // URLSessionInstrumentation intentionally not enabled: opentelemetry-swift's
        // swizzling crashes on iOS 26 / Swift 6 with dispatch_assert_queue isolation
        // checks (see github.com/open-telemetry/opentelemetry-swift/issues/937).
        // Re-enable once upstream ships a fix.

        tracer = tracerProvider.get(instrumentationName: "seer-app", instrumentationVersion: Bundle.main.appVersion)
        stableMeter = meterProvider
        otelLogger = logProvider.loggerBuilder(instrumentationScopeName: "seer-app").build()
    }

    private func buildResource() -> Resource {
        DefaultResources().get().merging(
            other: Resource(
                attributes: [
                    ResourceAttributes.serviceName.rawValue: AttributeValue.string("seer-ios"),
                    ResourceAttributes.serviceVersion.rawValue: AttributeValue.string(Bundle.main.appVersion),
                    ResourceAttributes.deploymentEnvironment.rawValue: AttributeValue.string("production"),
                    "app.build": AttributeValue.string(Bundle.main.buildNumber)
                ]
            )
        )
    }

    private func buildOtlpConfig() -> OtlpConfiguration {
        var headers: [(String, String)]?
        if let authHeader = Self.otlpAuthHeader {
            headers = [authHeader]
            Self.logger.debug("OTLP configured with auth header: \(authHeader.0)")
        }
        return OtlpConfiguration(headers: headers)
    }

    private func setupTracerProvider(
        resource: Resource,
        config: OtlpConfiguration,
        endpoint: String
    ) -> TracerProviderSdk? {
        guard let tracesURL = URL(string: "\(endpoint)/v1/traces") else {
            Self.logger.error("Invalid OTLP traces endpoint URL")
            return nil
        }
        let httpExporter = OtlpHttpTraceExporter(endpoint: tracesURL, config: config)

        // Wrap with persistence for offline buffering
        let spanExporter: SpanExporter
        do {
            let storageURL = Self.persistenceStorageURL.appendingPathComponent("spans", isDirectory: true)
            spanExporter = try PersistenceSpanExporterDecorator(
                spanExporter: httpExporter,
                storageURL: storageURL
            )
            Self.logger.debug("Persistence span exporter enabled at \(storageURL.path)")
        } catch {
            Self.logger.warning("Failed to create persistence span exporter: \(error). Using non-persistent exporter.")
            spanExporter = httpExporter
        }

        var providerBuilder = TracerProviderBuilder()
            .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
            .with(resource: resource)

        // Add SignPost integration for Xcode Instruments visibility
        #if DEBUG
            providerBuilder = providerBuilder.add(spanProcessor: SignPostIntegration())
            Self.logger.debug("SignPost integration enabled for Instruments tracing")
        #endif

        let provider = providerBuilder.build()
        OpenTelemetry.registerTracerProvider(tracerProvider: provider)
        return provider
    }

    private func setupMeterProvider(
        resource: Resource,
        config: OtlpConfiguration,
        endpoint: String
    ) -> StableMeterProviderSdk? {
        guard let metricsURL = URL(string: "\(endpoint)/v1/metrics") else {
            Self.logger.error("Invalid OTLP metrics endpoint URL")
            return nil
        }
        let exporter = StableOtlpHTTPMetricExporter(endpoint: metricsURL, config: config)
        // Note: PersistenceMetricExporterDecorator doesn't support StableMetricExporter yet
        let reader = StablePeriodicMetricReaderBuilder(exporter: exporter)
            .setInterval(timeInterval: 60.0)
            .build()
        let provider = StableMeterProviderSdk.builder()
            .setResource(resource: resource)
            .registerMetricReader(reader: reader)
            .build()
        OpenTelemetry.registerStableMeterProvider(meterProvider: provider)
        return provider
    }

    private func setupLoggerProvider(
        resource: Resource,
        config: OtlpConfiguration,
        endpoint: String
    ) -> LoggerProviderSdk? {
        guard let logsURL = URL(string: "\(endpoint)/v1/logs") else {
            Self.logger.error("Invalid OTLP logs endpoint URL")
            return nil
        }
        let exporter = OtlpHttpLogExporter(endpoint: logsURL, config: config)
        let processor = BatchLogRecordProcessor(logRecordExporter: exporter)
        let provider = LoggerProviderBuilder().with(resource: resource).with(processors: [processor]).build()
        OpenTelemetry.registerLoggerProvider(loggerProvider: provider)

        // Bootstrap Swift Logging to route logs through OpenTelemetry
        LoggingSystem.bootstrap { _ in
            OTelLogHandler(loggerProvider: provider)
        }
        Self.logger.debug("Swift Logging bootstrapped with OpenTelemetry log handler")

        return provider
    }

    /// Call this when consent changes to initialize or update OTEL
    public func onConsentChanged() {
        let consent = DiagnosticsConsent.shared

        if consent.crashReportsEnabled || consent.performanceMetricsEnabled {
            if !isInitialized {
                initializeIfConsented()
            }
        }
        // Note: OTEL doesn't easily support runtime disable, so we just stop sending new events
    }

    // MARK: - Public API (Feature Mapping from Errata)

    /// Add a breadcrumb event to the current trace
    public func addBreadcrumb(
        category: String,
        message: String,
        level: BreadcrumbLevel = .info,
        data: [String: Any]? = nil
    ) {
        guard isInitialized, let tracer else { return }

        let span = tracer.spanBuilder(spanName: "breadcrumb.\(category)").startSpan()

        var attributes: [String: AttributeValue] = [
            "breadcrumb.category": .string(category),
            "breadcrumb.message": .string(message),
            "breadcrumb.level": .string(level.rawValue)
        ]

        if let data {
            for (key, value) in data {
                attributes["breadcrumb.data.\(key)"] = attributeValue(from: value)
            }
        }

        span.addEvent(name: message, attributes: attributes)
        span.end()
    }

    /// Record a metric value
    public func recordMetric(name: String, value: Double, unit: String) {
        guard isInitialized, let stableMeter else { return }

        let meter = stableMeter.meterBuilder(name: "seer-app").build()
        var histogram = meter.histogramBuilder(name: name).build()
        histogram.record(value: value, attributes: ["unit": AttributeValue.string(unit)])
    }

    /// Capture a message with context
    public func captureMessage(_ message: String, level: BreadcrumbLevel = .info, context: [String: Any]? = nil) {
        guard isInitialized, let tracer else { return }

        let span = tracer.spanBuilder(spanName: "message").startSpan()

        var attributes: [String: AttributeValue] = [
            "message.content": .string(message),
            "message.level": .string(level.rawValue)
        ]

        if let context {
            for (key, value) in context {
                attributes["context.\(key)"] = attributeValue(from: value)
            }
        }

        span.addEvent(name: message, attributes: attributes)
        span.end()
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called when MetricKit delivers daily metric payloads containing performance data.
    public nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        guard !payloads.isEmpty else { return }

        let count = payloads.count
        let jsonDataList = payloads.map { $0.jsonRepresentation() }

        Task { @MainActor in
            guard DiagnosticsConsent.shared.performanceMetricsEnabled else {
                Self.logger.debug(
                    "Received \(count) metric payload(s) but performance metrics consent not granted - discarding"
                )
                return
            }

            Self.logger.info("Received \(count) metric payload(s)")

            for jsonData in jsonDataList {
                if isInitialized {
                    addBreadcrumb(
                        category: "metrics",
                        message: "MetricKit payload received",
                        level: .info,
                        data: ["payloadSize": jsonData.count]
                    )

                    if let metrics = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        recordMetricsFromPayload(metrics)
                    }
                }

                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    Self.logger.debug("Metric payload JSON: \(jsonString)")
                }
            }
        }
    }

    /// Called when MetricKit delivers diagnostic payloads containing crash reports.
    public nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }

        let count = payloads.count
        let jsonDataList = payloads.map { $0.jsonRepresentation() }

        Task { @MainActor in
            guard DiagnosticsConsent.shared.crashReportsEnabled else {
                Self.logger.debug(
                    "Received \(count) diagnostic payload(s) but crash reports consent not granted - discarding"
                )
                return
            }

            Self.logger.warning("Received \(count) diagnostic payload(s)")

            for jsonData in jsonDataList {
                if isInitialized {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        captureMessage(
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

    private func recordMetricsFromPayload(_ metrics: [String: Any]) {
        if let appLaunch = metrics["applicationLaunchMetrics"] as? [String: Any],
           let timeToFirstDraw = appLaunch["histogrammedTimeToFirstDraw"] as? [String: Any],
           let avg = timeToFirstDraw["averageValue"] as? Double {
            recordMetric(name: "app.launch.time_to_first_draw", value: avg, unit: "ms")
        }

        if let memoryMetrics = metrics["memoryMetrics"] as? [String: Any],
           let peakMemory = memoryMetrics["peakMemoryUsage"] as? Double {
            recordMetric(name: "app.memory.peak_usage", value: peakMemory, unit: "bytes")
        }

        if let cpuMetrics = metrics["cpuMetrics"] as? [String: Any],
           let cumulativeCPU = cpuMetrics["cumulativeCPUTime"] as? Double {
            recordMetric(name: "app.cpu.cumulative_time", value: cumulativeCPU, unit: "ms")
        }
    }

    private func attributeValue(from value: Any) -> AttributeValue {
        switch value {
        case let string as String:
            .string(string)
        case let int as Int:
            .int(int)
        case let double as Double:
            .double(double)
        case let bool as Bool:
            .bool(bool)
        default:
            .string(String(describing: value))
        }
    }
}

// MARK: - Breadcrumb Level

public enum BreadcrumbLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
    case fatal
}

// MARK: - Onboarding funnel events

public extension TelemetryService {
    /// Which welcome-screen suggestion the user picked.
    enum OnboardingPath: String, Sendable {
        case bonjour
        case icloud
        case manual
    }

    /// Which authentication method the user used to complete onboarding.
    enum OnboardingAuthMethod: String, Sendable {
        case quickConnect = "quickconnect"
        case password
    }

    /// Streamlined onboarding funnel events. Emitted only when
    /// `DiagnosticsConsent.performanceMetricsEnabled` is true (the
    /// `captureMessage` path already gates on `isInitialized`, which
    /// itself reflects consent). No PII: server hostnames, URLs, and
    /// usernames are never attached.
    func recordOnboardingWelcomeShown() {
        captureMessage("onboarding_welcome_shown")
    }

    func recordOnboardingPathSelected(_ path: OnboardingPath) {
        captureMessage("onboarding_path_selected", context: ["path": path.rawValue])
    }

    func recordOnboardingAuthMethod(_ method: OnboardingAuthMethod) {
        captureMessage("onboarding_auth_method", context: ["method": method.rawValue])
    }

    func recordOnboardingCompleted() {
        captureMessage("onboarding_completed")
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
