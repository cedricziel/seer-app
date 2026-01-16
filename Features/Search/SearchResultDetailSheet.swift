import JellyseerrClient
import SeerUI
import SwiftUI

// MARK: - Search Result Detail Sheet

struct SearchResultDetailSheet: View {
    let result: SearchResult
    var canRequest4K: Bool = false
    let onRequest: () -> Void
    let isRequesting: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top, spacing: 16) {
                        PosterImage(url: result.posterURL())
                            .frame(width: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                if let year = result.displayYear {
                                    Text(year)
                                }

                                MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tvShow)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            if let rating = result.voteAverage, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                            }

                            // Status
                            if result.isAvailable {
                                RequestStatusBadge(status: .available, style: .full)
                            } else if result.hasPendingRequest {
                                RequestStatusBadge(status: .pending, style: .full)
                            }
                        }
                    }

                    // Overview
                    if let overview = result.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)

                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Request Button
                    if !result.isAvailable, !result.hasPendingRequest {
                        Button(action: onRequest) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text(isRequesting ? "Requesting..." : "Request")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isRequesting)
                    } else if result.isAvailable {
                        Label("Already Available", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Label("Already Requested", systemImage: "clock")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
