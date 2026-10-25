import Foundation
import OpenTelemetrySdk

final class DiagnosticsSpanExporter: SpanExporter {
    private let exporter: any SpanExporter
    private let isEnabled: () -> Bool

    init(exporter: any SpanExporter, isEnabled: @escaping () -> Bool) {
        self.exporter = exporter
        self.isEnabled = isEnabled
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard isEnabled() else { return .success }
        return exporter.export(spans: spans, explicitTimeout: explicitTimeout)
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard isEnabled() else { return .success }
        return exporter.flush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
}

struct DiagnosticsLogExporter: LogRecordExporter {
    let exporter: any LogRecordExporter
    let isEnabled: () -> Bool

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        guard isEnabled() else { return .success }
        return exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        guard isEnabled() else { return .success }
        return exporter.forceFlush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
}

struct DiagnosticsMetricExporter: StableMetricExporter {
    let exporter: any StableMetricExporter
    let isEnabled: () -> Bool

    func export(metrics: [StableMetricData]) -> ExportResult {
        guard isEnabled() else { return .success }
        return exporter.export(metrics: metrics)
    }

    func flush() -> ExportResult {
        guard isEnabled() else { return .success }
        return exporter.flush()
    }

    func shutdown() -> ExportResult {
        exporter.shutdown()
    }

    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
        exporter.getAggregationTemporality(for: instrument)
    }

    func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
        exporter.getDefaultAggregation(for: instrument)
    }
}
