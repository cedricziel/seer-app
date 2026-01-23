import CrashReporter
import OpenTelemetryApi
import OSLog

/// Bridge between PLCrashReporter and OpenTelemetry.
/// Processes pending crash reports from previous sessions and emits them as OTEL log events.
///
/// Crashes are emitted as FATAL severity log events following OTEL semantic conventions.
public final class CrashReportBridge: @unchecked Sendable {
    /// Shared instance
    public static let shared = CrashReportBridge()

    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "CrashReportBridge")

    /// PLCrashReporter instance
    private var crashReporter: PLCrashReporter?

    /// OpenTelemetry logger for emitting crash reports
    private var otelLogger: OpenTelemetryApi.Logger?

    private init() {}

    /// Initialize the crash reporter with an OTEL logger
    /// - Parameter logger: OpenTelemetry logger instance for emitting crash report events
    public func initialize(logger: OpenTelemetryApi.Logger) {
        otelLogger = logger

        // Configure PLCrashReporter
        let config = PLCrashReporterConfig(
            signalHandlerType: .BSD,
            symbolicationStrategy: .all
        )

        guard let reporter = PLCrashReporter(configuration: config) else {
            Self.logger.error("Failed to create PLCrashReporter instance")
            return
        }

        crashReporter = reporter

        // Check for pending crash report from previous session
        if reporter.hasPendingCrashReport() {
            Self.logger.info("Found pending crash report from previous session")
            processPendingCrashReport()
        }

        // Enable crash reporter for this session
        reporter.enable()
        Self.logger.info("PLCrashReporter enabled successfully")
    }

    /// Process any pending crash report from a previous session
    private func processPendingCrashReport() {
        guard let crashReporter,
              let data = try? crashReporter.loadPendingCrashReportDataAndReturnError(),
              let report = try? PLCrashReport(data: data),
              let otelLogger else {
            Self.logger.warning("Failed to load or parse pending crash report")
            crashReporter?.purgePendingCrashReport()
            return
        }

        // Get crash signal information
        let signalName = report.signalInfo.name ?? "Unknown"
        let signalCode = report.signalInfo.code ?? "Unknown"

        // Build stack trace string
        var stackTraceLines: [String] = []

        if let crashedThread = report.threads.first(where: { ($0 as? PLCrashReportThreadInfo)?.crashed == true })
            as? PLCrashReportThreadInfo {
            for frame in crashedThread.stackFrames {
                guard let frameInfo = frame as? PLCrashReportStackFrameInfo else { continue }

                let symbolName = frameInfo.symbolInfo?.symbolName ?? "???"
                let imageName = report.images.first { image in
                    guard let imageInfo = image as? PLCrashReportBinaryImageInfo else { return false }
                    let imageBase = imageInfo.imageBaseAddress
                    let imageEnd = imageBase + imageInfo.imageSize
                    return frameInfo.instructionPointer >= imageBase && frameInfo.instructionPointer < imageEnd
                }.flatMap { ($0 as? PLCrashReportBinaryImageInfo)?.imageName } ?? "???"

                stackTraceLines.append("\(imageName) \(symbolName) + \(frameInfo.instructionPointer)")
            }
        }

        let stackTrace = stackTraceLines.joined(separator: "\n")

        // Get exception info if available
        let exceptionType = report.exceptionInfo?.exceptionName ?? signalName
        let exceptionMessage = report.exceptionInfo?.exceptionReason ?? "Signal \(signalCode)"

        // Get process info
        let processName = report.processInfo?.processName ?? "unknown"

        // Get timestamp
        let crashTimestamp = report.systemInfo.timestamp?.description ?? ""

        // Emit as FATAL log event
        otelLogger.logRecordBuilder()
            .setSeverity(.fatal)
            .setBody(AttributeValue.string("Application crashed: \(signalName)"))
            .setAttributes([
                "exception.type": AttributeValue.string(exceptionType),
                "exception.message": AttributeValue.string(exceptionMessage),
                "exception.stacktrace": AttributeValue.string(stackTrace),
                "crash.signal.name": AttributeValue.string(signalName),
                "crash.signal.code": AttributeValue.string(signalCode),
                "crash.process.name": AttributeValue.string(processName),
                "crash.timestamp": AttributeValue.string(crashTimestamp)
            ])
            .emit()

        Self.logger.info("Crash report emitted to OTEL: \(signalName) - \(exceptionMessage)")

        // Purge the crash report after processing
        crashReporter.purgePendingCrashReport()
        Self.logger.debug("Pending crash report purged")
    }
}
