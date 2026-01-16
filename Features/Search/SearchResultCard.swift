import JellyseerrClient
import SeerUI
import SwiftUI

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    var onViewDetails: (() -> Void)?
    var onRequest: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            ZStack(alignment: .topTrailing) {
                PosterImage(url: result.posterURL())

                // Status indicator
                if result.isAvailable {
                    RequestStatusBadge(status: .available, style: .compact)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                } else if result.hasPendingRequest {
                    RequestStatusBadge(status: .pending, style: .compact)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let year = result.displayYear {
                        Text(year)
                    }

                    MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tvShow)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            searchResultContextMenu
        }
    }

    @ViewBuilder
    private var searchResultContextMenu: some View {
        // View Details
        if let onViewDetails {
            Button {
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }

        // Request (if not already available or pending)
        if !result.isAvailable && !result.hasPendingRequest, let onRequest {
            Button {
                onRequest()
            } label: {
                Label("Request", systemImage: "plus.circle")
            }
        }
    }
}
