import JellyseerrClient
import SeerUI
import SwiftUI

// MARK: - Request Options Sheet

struct RequestOptionsSheet: View {
    let result: SearchResult
    @ObservedObject var viewModel: SearchViewModel
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
                // Title section
                Section {
                    HStack(spacing: 12) {
                        if let posterPath = result.posterPath {
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                            }
                            .frame(width: 60, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.displayTitle)
                                .font(.headline)
                            if let year = result.displayYear {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tvShow)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Season selection for TV shows
                if isTV {
                    Section {
                        if viewModel.isLoadingTVDetails {
                            HStack {
                                ProgressView()
                                Text("Loading seasons...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if viewModel.hasSeasons {
                            Button {
                                if selectedSeasons.count == viewModel.availableSeasons.count {
                                    selectedSeasons.removeAll()
                                } else {
                                    selectedSeasons = Set(viewModel.availableSeasons.map(\.seasonNumber))
                                }
                            } label: {
                                HStack {
                                    Text("Select All")
                                    Spacer()
                                    if selectedSeasons.count == viewModel.availableSeasons.count {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)

                            ForEach(viewModel.availableSeasons, id: \.seasonNumber) { season in
                                Button {
                                    toggleSeason(season.seasonNumber)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(season.name ?? "Season \(season.seasonNumber)")
                                            if let episodeCount = season.episodeCount {
                                                Text("\(episodeCount) episodes")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if selectedSeasons.contains(season.seasonNumber) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        } else {
                            Text("No seasons available")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Seasons")
                    } footer: {
                        Text("Select which seasons you want to request")
                    }
                }

                // 4K option
                if canRequest4K {
                    Section {
                        Toggle("Request in 4K", isOn: $request4K)
                    } footer: {
                        Text("Request the 4K version if available")
                    }
                }
            }
            .navigationTitle("Request Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Request") {
                        submitRequest()
                    }
                    .fontWeight(.semibold)
                    .disabled(isTV && selectedSeasons.isEmpty && !viewModel.isLoadingTVDetails)
                }
            }
        }
        .onAppear {
            // Pre-select all seasons by default
            if viewModel.hasSeasons {
                selectedSeasons = Set(viewModel.availableSeasons.map(\.seasonNumber))
            }
        }
        .onChange(of: viewModel.hasSeasons) {
            // Update selection when seasons are loaded
            if viewModel.hasSeasons, selectedSeasons.isEmpty {
                selectedSeasons = Set(viewModel.availableSeasons.map(\.seasonNumber))
            }
        }
    }

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
