import DownloadClient
import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

// MARK: - UI Sections Extension

extension MediaDetailView {
    // MARK: - Header Section

    var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            PosterImage(url: viewModel.imageURL(for: item), cornerRadius: 8)
                .frame(width: 100)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let originalTitle = item.originalTitle, originalTitle != item.name {
                    Text(originalTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if let year = item.year {
                        Text(String(year))
                    }

                    if let runtime = item.formattedRuntime {
                        Text(runtime)
                    }

                    if let rating = item.officialRating {
                        Text(rating)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // Rating
                if let rating = item.communityRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }

                // Media Type Badge
                MediaTypeBadge(type: item.type == .movie ? .movie : .tvShow)
            }
        }
    }

    // MARK: - Play Button

    var playButton: some View {
        HStack(spacing: 12) {
            Button {
                showPlayer = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text(hasProgress ? "Resume" : "Play")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Download button
            if downloadManager != nil {
                downloadButton
            }
        }
    }

    // MARK: - Download Button

    var downloadButton: some View {
        DownloadButton(
            state: downloadState,
            onDownload: {
                Task { await startDownload() }
            },
            onPause: {
                Task { await pauseDownload() }
            },
            onResume: {
                Task { await resumeDownload() }
            },
            onCancel: {
                Task { await cancelDownload() }
            },
            onDelete: {
                Task { await deleteDownload() }
            }
        )
        .frame(width: 130)
        .task {
            await updateDownloadState()
        }
    }

    // MARK: - Overview Section

    func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)

            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Genres Section

    func genresSection(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Cast Section

    func castSection(_ people: [MediaItem.Person]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(people.prefix(10), id: \.name) { person in
                        VStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                }

                            Text(person.name ?? "Unknown")
                                .font(.caption)
                                .lineLimit(1)

                            if let role = person.role {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    // MARK: - Seasons Section

    var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.headline)

            if let viewModel = seriesViewModel {
                if viewModel.isLoadingSeasons {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.seasons.isEmpty {
                    Text("No seasons available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.seasons) { season in
                        let episodes = viewModel.episodesBySeason[season.id] ?? []
                        SeasonDisclosureRow(
                            season: season,
                            episodes: episodes,
                            isExpanded: viewModel.expandedSeasons.contains(season.id),
                            isLoading: viewModel.isLoadingEpisodes[season.id] ?? false,
                            onToggle: {
                                Task {
                                    await viewModel.toggleSeason(season.id)
                                }
                            },
                            imageURL: { viewModel.imageURL(for: $0, type: .primary) },
                            onPlayEpisode: { episode in
                                selectedEpisodeForPlayback = episode
                                showPlayer = true
                            },
                            onTapEpisode: { episode in
                                selectedEpisodeForDetail = episode
                                showEpisodeDetail = true
                            },
                            onDownloadEpisode: { episode in
                                await downloadEpisode(episode)
                            },
                            onDownloadSeason: {
                                await downloadSeason(episodes: episodes)
                            },
                            downloadStateForEpisode: { episode in
                                episodeDownloadStates[episode.id] ?? .notDownloaded
                            }
                        )
                        .task {
                            await updateEpisodeDownloadStates(episodes: episodes)
                        }
                    }
                }
            }
        }
    }
}
