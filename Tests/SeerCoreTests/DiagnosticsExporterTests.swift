import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import SeerCore
import XCTest

final class DiagnosticsExporterTests: XCTestCase {
    func testSpanOptOutDropsQueuedExportsAndFlushes() {
        let sink = RecordingSpanExporter()
        let gate = DiagnosticsSpanExporter(exporter: sink, isEnabled: { false })
        XCTAssertEqual(gate.export(spans: [], explicitTimeout: nil), .success)
        XCTAssertEqual(gate.flush(explicitTimeout: nil), .success)
        XCTAssertEqual(sink.exports, 0)
        XCTAssertEqual(sink.flushes, 0)
    }

    func testEnabledSpansReachExporter() {
        let sink = RecordingSpanExporter()
        let gate = DiagnosticsSpanExporter(exporter: sink, isEnabled: { true })
        _ = gate.export(spans: [], explicitTimeout: nil)
        XCTAssertEqual(sink.exports, 1)
    }

    func testLogOptOutDropsQueuedExportsAndFlushes() {
        let sink = RecordingLogExporter()
        let gate = DiagnosticsLogExporter(exporter: sink, isEnabled: { false })
        XCTAssertEqual(gate.export(logRecords: [], explicitTimeout: nil), .success)
        XCTAssertEqual(gate.forceFlush(explicitTimeout: nil), .success)
        XCTAssertEqual(sink.exports, 0)
        XCTAssertEqual(sink.flushes, 0)
    }

    func testMetricOptOutDropsExportsAndFlushes() {
        let sink = RecordingMetricExporter()
        let gate = DiagnosticsMetricExporter(exporter: sink, isEnabled: { false })
        XCTAssertEqual(gate.export(metrics: []), .success)
        XCTAssertEqual(gate.flush(), .success)
        XCTAssertEqual(sink.exports, 0)
        XCTAssertEqual(sink.flushes, 0)
    }

    func testSettingsAreRecheckedAfterExporterInitialization() throws {
        let suite = "seer.exporter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DiagnosticsPreferences(defaults: defaults)
        let sink = RecordingSpanExporter()
        let gate = DiagnosticsSpanExporter(exporter: sink, isEnabled: { preferences.performanceMetricsEnabled })
        _ = gate.export(spans: [], explicitTimeout: nil)
        preferences.performanceMetricsEnabled = false
        _ = gate.export(spans: [], explicitTimeout: nil)
        XCTAssertEqual(sink.exports, 1)
    }
}

private final class RecordingSpanExporter: SpanExporter {
    private let counts = Locked(initialValue: ExportCounts())

    var exports: Int {
        counts.locking { $0.exports }
    }

    var flushes: Int {
        counts.locking { $0.flushes }
    }

    func export(spans _: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        counts.locking { $0.exports += 1 }
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        counts.locking { $0.flushes += 1 }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}

private final class RecordingLogExporter: LogRecordExporter {
    private let counts = Locked(initialValue: ExportCounts())

    var exports: Int {
        counts.locking { $0.exports }
    }

    var flushes: Int {
        counts.locking { $0.flushes }
    }

    func export(logRecords _: [ReadableLogRecord], explicitTimeout _: TimeInterval?) -> ExportResult {
        counts.locking { $0.exports += 1 }
        return .success
    }

    func forceFlush(explicitTimeout _: TimeInterval?) -> ExportResult {
        counts.locking { $0.flushes += 1 }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}

private final class RecordingMetricExporter: MetricExporter {
    private let counts = Locked(initialValue: ExportCounts())

    var exports: Int {
        counts.locking { $0.exports }
    }

    var flushes: Int {
        counts.locking { $0.flushes }
    }

    func export(metrics _: [MetricData]) -> ExportResult {
        counts.locking { $0.exports += 1 }
        return .success
    }

    func flush() -> ExportResult {
        counts.locking { $0.flushes += 1 }
        return .success
    }

    func shutdown() -> ExportResult {
        .success
    }

    func getAggregationTemporality(for _: InstrumentType) -> AggregationTemporality {
        .cumulative
    }
}

private struct ExportCounts {
    var exports = 0
    var flushes = 0
}
