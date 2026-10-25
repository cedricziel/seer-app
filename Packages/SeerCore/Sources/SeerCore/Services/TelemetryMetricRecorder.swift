import OpenTelemetryApi
import OpenTelemetrySdk

enum TelemetryMetricRecorder {
    static func makeProvider(reader: any MetricReader, resource: Resource) -> MeterProviderSdk {
        // The SDK view registry has no default histogram fallback.
        let selector = InstrumentSelector.builder().setInstrument(type: .histogram).setMeter(name: "seer-app").build()
        let view = View.builder().withAggregation(aggregation: Aggregations.explicitBucketHistogram()).build()
        return MeterProviderSdk.builder()
            .setResource(resource: resource)
            .registerMetricReader(reader: reader)
            .registerView(selector: selector, view: view)
            .build()
    }

    static func record(name: String, value: Double, unit: String, provider: any MeterProvider) {
        let meter = provider.meterBuilder(name: "seer-app").build()
        var histogram = meter.histogramBuilder(name: name).build()
        histogram.record(value: value, attributes: ["unit": .string(unit)])
    }
}
