import OpenTelemetryApi
import OpenTelemetrySdk
@testable import SeerCore
import XCTest

final class TelemetryMetricRecorderTests: XCTestCase {
    func testRecordingPreservesMetricNameValueAndUnitAttribute() throws {
        let reader = CollectingMetricReader()
        let provider = TelemetryMetricRecorder.makeProvider(reader: reader, resource: Resource())
        defer { _ = provider.shutdown() }

        TelemetryMetricRecorder.record(name: "app.launch.time", value: 12.5, unit: "ms", provider: provider)

        let metric = try XCTUnwrap(reader.collect().first)
        let point = try XCTUnwrap(metric.data.points.first as? HistogramPointData)
        XCTAssertEqual(metric.name, "app.launch.time")
        XCTAssertEqual(metric.instrumentationScopeInfo.name, "seer-app")
        XCTAssertEqual(metric.type, .Histogram)
        XCTAssertEqual(point.sum, 12.5)
        XCTAssertEqual(point.count, 1)
        XCTAssertEqual(point.attributes["unit"], .string("ms"))
    }

    func testRepeatedRecordingsAccumulateInTheSameHistogram() throws {
        let reader = CollectingMetricReader()
        let provider = TelemetryMetricRecorder.makeProvider(reader: reader, resource: Resource())
        defer { _ = provider.shutdown() }

        TelemetryMetricRecorder.record(name: "app.memory.peak", value: 8, unit: "bytes", provider: provider)
        TelemetryMetricRecorder.record(name: "app.memory.peak", value: 16, unit: "bytes", provider: provider)

        let metrics = reader.collect()
        let point = try XCTUnwrap(metrics.first?.data.points.first as? HistogramPointData)
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(point.count, 2)
        XCTAssertEqual(point.sum, 24)
    }
}

private final class CollectingMetricReader: MetricReader {
    private let producer = Locked<(any MetricProducer)?>(initialValue: nil)

    func register(registration: any CollectionRegistration) {
        producer.locking { $0 = registration as? any MetricProducer }
    }

    func collect() -> [MetricData] {
        producer.locking { $0?.collectAllMetrics() ?? [] }
    }

    func forceFlush() -> ExportResult {
        .success
    }

    func shutdown() -> ExportResult {
        .success
    }

    func getAggregationTemporality(for _: InstrumentType) -> AggregationTemporality {
        .cumulative
    }

    func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
        AggregationSelector.instance.getDefaultAggregation(for: instrument)
    }
}
