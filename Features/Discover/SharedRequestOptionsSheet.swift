import JellyseerrClient
import SeerUI
import SwiftUI

// MARK: - Request Options Provider Protocol

/// Protocol for view models that can provide TV details and request options
@MainActor
protocol RequestOptionsProvider: ObservableObject {
    var isLoadingTVDetails: Bool { get }
    var tvDetails: TVDetails? { get }

    var hasSeasons: Bool { get }
    var availableSeasons: [TVDetails.Season] { get }
}

// MARK: - Shared Request Options Sheet

/// A reusable request options sheet that works with any RequestOptionsProvider
struct SharedRequestOptionsSheet<Provider: RequestOptionsProvider>: View {
    let result: SearchResult
    @ObservedObject var provider: Provider
    var canRequest4K: Bool
    let onSubmit: ([Int]?, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeasons: Set<Int> = []
    @State private var request4K: Bool = false

    private var isTV: Bool {
        result.mediaType == .tvShow
    }

    var body: some View {
        NavigationStack {
            List {
                titleSection
                if isTV { seasonSelectionSection }
                if canRequest4K { fourKSection }
            }
            .navigationTitle("Request Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Request") { submitRequest() }
                        .fontWeight(.semibold)
                        .disabled(isTV && selectedSeasons.isEmpty && !provider.isLoadingTVDetails)
                }
            }
        }
        .onAppear {
            if provider.hasSeasons {
                selectedSeasons = Set(provider.availableSeasons.map(\.seasonNumber))
            }
        }
        .onChange(of: provider.hasSeasons) {
            if provider.hasSeasons, selectedSeasons.isEmpty {
                selectedSeasons = Set(provider.availableSeasons.map(\.seasonNumber))
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            HStack(spacing: 12) {
                posterView
                titleInfo
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var posterView: some View {
        if let posterPath = result.posterPath {
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var titleInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.displayTitle).font(.headline)
            if let year = result.displayYear {
                Text(year).font(.subheadline).foregroundStyle(.secondary)
            }
            MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tvShow)
        }
    }

    private var seasonSelectionSection: some View {
        Section {
            if provider.isLoadingTVDetails {
                HStack {
                    ProgressView()
                    Text("Loading seasons...").foregroundStyle(.secondary)
                }
            } else if provider.hasSeasons {
                selectAllButton
                ForEach(provider.availableSeasons, id: \.seasonNumber) { season in
                    seasonButton(for: season)
                }
            } else {
                Text("No seasons available").foregroundStyle(.secondary)
            }
        } header: {
            Text("Seasons")
        } footer: {
            Text("Select which seasons you want to request")
        }
    }

    private var selectAllButton: some View {
        Button {
            if selectedSeasons.count == provider.availableSeasons.count {
                selectedSeasons.removeAll()
            } else {
                selectedSeasons = Set(provider.availableSeasons.map(\.seasonNumber))
            }
        } label: {
            HStack {
                Text("Select All")
                Spacer()
                if selectedSeasons.count == provider.availableSeasons.count {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func seasonButton(for season: TVDetails.Season) -> some View {
        Button {
            toggleSeason(season.seasonNumber)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(season.name ?? "Season \(season.seasonNumber)")
                    if let episodeCount = season.episodeCount {
                        Text("\(episodeCount) episodes")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedSeasons.contains(season.seasonNumber) {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var fourKSection: some View {
        Section {
            Toggle("Request in 4K", isOn: $request4K)
        } footer: {
            Text("Request the 4K version if available")
        }
    }

    // MARK: - Actions

    private func toggleSeason(_ seasonNumber: Int) {
        if selectedSeasons.contains(seasonNumber) {
            selectedSeasons.remove(seasonNumber)
        } else {
            selectedSeasons.insert(seasonNumber)
        }
    }

    private func submitRequest() {
        let seasons: [Int]? = isTV ? Array(selectedSeasons).sorted() : nil
        onSubmit(seasons, request4K)
    }
}
