import JellyfinClient
import SwiftUI

// MARK: - Series Section (season chip row + selected-season episode list)

extension MediaDetailView {
    /// Season chip row, "N episodes · M watched" caption, "Download season"
    /// action and the `EpisodeRow` list for the currently selected season.
    var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.headline)

            if let seriesViewModel {
                seasonsContent(for: seriesViewModel)
            }
        }
    }

    @ViewBuilder
    private func seasonsContent(for seriesVM: SeriesDetailViewModel) -> some View {
        if seriesVM.isLoadingSeasons {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if seriesVM.seasons.isEmpty {
            Text("No seasons available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            seasonChipRow(seriesVM: seriesVM)

            if let selectedSeasonID = seriesVM.selectedSeasonID {
                // Both the caption and the episode list key off the same
                // `isLoadingEpisodes` flag, so they always agree on whether
                // the season is still loading, loaded-and-empty, or failed
                // (in which case both simply show empty, rather than the
                // caption spinning forever while the list is already blank).
                let isLoadingEpisodes = seriesVM.isLoadingEpisodes[selectedSeasonID] == true
                let episodes = seriesVM.episodesBySeason[selectedSeasonID] ?? []

                seasonCaptionRow(isLoading: isLoadingEpisodes, episodes: episodes)
                selectedSeasonEpisodeList(isLoading: isLoadingEpisodes, episodes: episodes, seriesVM: seriesVM)
            }
        }
    }

    // MARK: - Season Chip Row

    private func seasonChipRow(seriesVM: SeriesDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(seriesVM.seasons) { season in
                    seasonChip(season, seriesVM: seriesVM)
                }
            }
        }
    }

    private func seasonChip(_ season: MediaItem, seriesVM: SeriesDetailViewModel) -> some View {
        let isSelected = seriesVM.selectedSeasonID == season.id
        return Button {
            Task { await seriesVM.selectSeason(season.id) }
        } label: {
            Text(season.name)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(isSelected ? Color.accentColor : Color.seasonChipFill)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Caption + Download Season

    private func seasonCaptionRow(isLoading: Bool, episodes: [MediaItem]) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                let watchedCount = episodes.count(where: { $0.userData?.played == true })
                Text("\(episodes.count) episodes · \(watchedCount) watched")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isLoading, !episodes.isEmpty {
                Button {
                    Task { await downloadSeason(episodes: episodes) }
                } label: {
                    Text("Download season")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Episode List

    @ViewBuilder
    private func selectedSeasonEpisodeList(
        isLoading: Bool,
        episodes: [MediaItem],
        seriesVM: SeriesDetailViewModel
    ) -> some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            ForEach(episodes) { episode in
                EpisodeRow(
                    episode: episode,
                    imageURL: seriesVM.imageURL(for: episode, type: .primary),
                    onPlay: {
                        selectedEpisodeForPlayback = episode
                        showPlayer = true
                    },
                    onTap: {
                        selectedEpisodeForDetail = episode
                        showEpisodeDetail = true
                    },
                    onDownload: {
                        await downloadEpisode(episode)
                    },
                    downloadState: downloadStateFor(episodeID: episode.id)
                )
            }
        }
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var seasonChipFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}
