import SwiftUI

// MARK: - Overview Section

extension MediaDetailView {
    /// Overview body text, collapsed to 4 lines by default with an accent
    /// "More"/"Less" toggle bound to `isOverviewExpanded`. The toggle only
    /// appears when the text actually overflows 4 lines.
    func overviewSection(_ overview: String) -> some View {
        MeasuredOverviewText(overview: overview, isExpanded: $isOverviewExpanded)
    }
}

/// Renders `overview` clamped to 4 lines (or fully, once expanded) and shows
/// a "More"/"Less" toggle only when the text is long enough to be truncated
/// at 4 lines. Truncation is detected by measuring the full, unclamped
/// height of the text against its 4-line-clamped height at the same width.
private struct MeasuredOverviewText: View {
    let overview: String
    @Binding var isExpanded: Bool

    @State private var fullHeight: CGFloat = 0
    @State private var clampedHeight: CGFloat = 0

    private var isTruncated: Bool {
        fullHeight > clampedHeight + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 4)
                .background(heightMeasurers)

            if isTruncated {
                Button(isExpanded ? "Less" : "More") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    /// Two hidden copies of the text - one unclamped, one clamped to 4
    /// lines - measured at the width the visible text resolves to.
    private var heightMeasurers: some View {
        ZStack {
            Text(overview)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: OverviewFullHeightKey.self, value: proxy.size.height)
                    }
                )

            Text(overview)
                .font(.body)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: OverviewClampedHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .onPreferenceChange(OverviewFullHeightKey.self) { fullHeight = $0 }
        .onPreferenceChange(OverviewClampedHeightKey.self) { clampedHeight = $0 }
    }
}

private struct OverviewFullHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct OverviewClampedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
