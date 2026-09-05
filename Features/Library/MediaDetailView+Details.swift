import JellyfinClient
import SwiftUI

// MARK: - Details Section Extension

extension MediaDetailView {
    /// A single labeled row in the Details section.
    private struct DetailRowData {
        let label: String
        let value: String
    }

    /// Plain, hairline-separated list of Director / Studio / Premiered.
    /// Rows with no backing data are omitted individually; the whole
    /// section (including its heading) is omitted when no rows remain.
    /// `Added` (dateCreated) is intentionally not rendered — `MediaItem`
    /// has no such field.
    @ViewBuilder
    var detailsSection: some View {
        let rows = detailRows(for: displayItem)

        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.label) { index, row in
                        if index > 0 {
                            Divider()
                        }
                        detailRow(label: row.label, value: row.value)
                    }
                }
            }
        }
    }

    private func detailRows(for item: MediaItem) -> [DetailRowData] {
        var rows: [DetailRowData] = []

        if let director = item.people?.first(where: { $0.type == "Director" })?.name {
            rows.append(DetailRowData(label: "Director", value: director))
        }

        if let studio = item.studios?.first?.name {
            rows.append(DetailRowData(label: "Studio", value: studio))
        }

        if let premiereDate = item.premiereDate {
            let value = premiereDate.formatted(date: .abbreviated, time: .omitted)
            rows.append(DetailRowData(label: "Premiered", value: value))
        }

        return rows
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
    }
}
