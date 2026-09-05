import JellyfinClient
import Kingfisher
import SeerUI
import SwiftUI

// MARK: - UI Sections Extension

extension MediaDetailView {
    // MARK: - Format Info Section

    @ViewBuilder
    var formatInfoSection: some View {
        let formatItem = displayItem
        let hasFormatInfo = formatItem.formattedVideoInfo != nil ||
            formatItem.formattedAudioInfo != nil ||
            formatItem.formattedContainer != nil

        if hasFormatInfo {
            VStack(alignment: .leading, spacing: 12) {
                Text("Format")
                    .font(.headline)

                HStack(spacing: 8) {
                    if let videoInfo = formatItem.formattedVideoInfo {
                        formatBadge(icon: "video", label: "Video", value: videoInfo)
                    }

                    if let audioInfo = formatItem.formattedAudioInfo {
                        formatBadge(icon: "speaker.wave.2", label: "Audio", value: audioInfo)
                    }

                    if let container = formatItem.formattedContainer {
                        formatBadge(icon: "doc", label: "File", value: container)
                    }
                }
            }
        }
    }

    private func formatBadge(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.formatBadgeFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .background(Color.genrePillFill)
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
                    ForEach(Array(people.prefix(10).enumerated()), id: \.offset) { _, person in
                        castCell(for: person)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func castCell(for person: MediaItem.Person) -> some View {
        if person.id != nil {
            NavigationLink(value: person) {
                castCellContent(for: person)
            }
            .buttonStyle(.plain)
        } else {
            castCellContent(for: person)
        }
    }

    private func castCellContent(for person: MediaItem.Person) -> some View {
        VStack {
            Group {
                if let url = viewModel.personImageURL(for: person) {
                    KFImage(url)
                        .placeholder { castPlaceholder }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    castPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())

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

    private var castPlaceholder: some View {
        Circle()
            .fill(Color.castPlaceholderFill)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
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
                                downloadStateFor(episodeID: episode.id)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var formatBadgeFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray6)
        #else
            Color.gray.opacity(0.12)
        #endif
    }

    static var genrePillFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.15)
        #endif
    }

    static var castPlaceholderFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.15)
        #endif
    }
}
