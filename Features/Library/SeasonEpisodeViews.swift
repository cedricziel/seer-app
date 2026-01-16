import JellyfinClient
import SwiftUI

/// Expandable row displaying a season with its episodes
struct SeasonDisclosureRow: View {
    let season: MediaItem
    let episodes: [MediaItem]
    let isExpanded: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    let imageURL: (MediaItem) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Season header (tappable)
            Button(action: onToggle) {
                HStack {
                    Text(season.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if !episodes.isEmpty || isExpanded {
                        Text("\(episodes.count) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Episodes list (if expanded)
            if isExpanded {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(episodes) { episode in
                        EpisodeRow(episode: episode, imageURL: imageURL(episode))
                    }
                }
            }

            Divider()
        }
    }
}

/// Row displaying an episode with thumbnail and metadata
struct EpisodeRow: View {
    let episode: MediaItem
    let imageURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 100, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(episodeTitle)
                    .font(.subheadline)
                    .lineLimit(1)

                if let runtime = episode.formattedRuntime {
                    Text(runtime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Watch status indicator
            if episode.userData?.played == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
    }

    private var episodeTitle: String {
        if let episodeNumber = episode.indexNumber {
            return "E\(episodeNumber): \(episode.name)"
        }
        return episode.name
    }
}
