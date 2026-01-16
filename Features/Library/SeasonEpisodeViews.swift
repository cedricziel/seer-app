import DownloadClient
import JellyfinClient
import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

/// Expandable row displaying a season with its episodes
struct SeasonDisclosureRow: View {
    let season: MediaItem
    let episodes: [MediaItem]
    let isExpanded: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    let imageURL: (MediaItem) -> URL?
    var onPlayEpisode: ((MediaItem) -> Void)?
    var onTapEpisode: ((MediaItem) -> Void)?
    var onDownloadEpisode: ((MediaItem) async -> Void)?
    var onDownloadSeason: (() async -> Void)?
    var downloadStateForEpisode: ((MediaItem) -> DownloadButtonState)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Season header (tappable)
            HStack {
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

                // Download season button
                if let onDownloadSeason, !episodes.isEmpty {
                    Button {
                        Task { await onDownloadSeason() }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
            }

            // Episodes list (if expanded)
            if isExpanded {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(episodes) { episode in
                        EpisodeRow(
                            episode: episode,
                            imageURL: imageURL(episode),
                            onPlay: onPlayEpisode != nil ? { onPlayEpisode?(episode) } : nil,
                            onTap: onTapEpisode != nil ? { onTapEpisode?(episode) } : nil,
                            onDownload: onDownloadEpisode != nil ? { await onDownloadEpisode?(episode) } : nil,
                            downloadState: downloadStateForEpisode?(episode) ?? .notDownloaded
                        )
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
    var onPlay: (() -> Void)?
    var onTap: (() -> Void)?
    var onDownload: (() async -> Void)?
    var onDeleteDownload: (() -> Void)?
    var onMarkWatched: ((Bool) -> Void)?
    var downloadState: DownloadButtonState = .notDownloaded

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Thumbnail with play overlay
                ZStack {
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

                    // Progress bar overlay
                    if let progress = progressPercentage {
                        VStack {
                            Spacer()
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * progress, height: 3)
                            }
                            .frame(height: 3)
                        }
                        .frame(width: 100, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(episodeTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let runtime = episode.formattedRuntime {
                            Text(runtime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Resume indicator
                        if hasProgress {
                            Text("Resume")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }

                        // Downloaded indicator
                        if downloadState == .completed {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                // Download button
                if let onDownload {
                    CompactDownloadButton(
                        state: downloadState,
                        onDownload: { Task { await onDownload() } },
                        onCancel: {}
                    )
                }

                // Play button or watch status indicator
                if let onPlay {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else if isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 16)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .contextMenu {
            episodeContextMenu
        }
    }

    @ViewBuilder
    private var episodeContextMenu: some View {
        // Play
        if let onPlay {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
        }

        // Download / Delete Download
        if downloadState == .completed {
            if let onDeleteDownload {
                Button(role: .destructive) {
                    onDeleteDownload()
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            }
        } else if let onDownload {
            Button {
                Task { await onDownload() }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        }

        // Mark as Watched / Unwatched
        if let onMarkWatched {
            Divider()

            if isWatched {
                Button {
                    onMarkWatched(false)
                } label: {
                    Label("Mark as Unwatched", systemImage: "eye.slash")
                }
            } else {
                Button {
                    onMarkWatched(true)
                } label: {
                    Label("Mark as Watched", systemImage: "eye")
                }
            }
        }
    }

    private var isWatched: Bool {
        episode.userData?.played == true
    }

    private var episodeTitle: String {
        if let episodeNumber = episode.indexNumber {
            return "E\(episodeNumber): \(episode.name)"
        }
        return episode.name
    }

    private var hasProgress: Bool {
        guard let ticks = episode.userData?.playbackPositionTicks else { return false }
        return ticks > 0
    }

    private var progressPercentage: Double? {
        guard let positionTicks = episode.userData?.playbackPositionTicks,
              let durationTicks = episode.runTimeTicks,
              durationTicks > 0
        else {
            return nil
        }
        return Double(positionTicks) / Double(durationTicks)
    }
}

// MARK: - Compact Download Button

/// A smaller download button for use in list rows
public struct CompactDownloadButton: View {
    let state: DownloadButtonState
    let onDownload: () -> Void
    let onCancel: () -> Void

    public init(
        state: DownloadButtonState,
        onDownload: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.state = state
        self.onDownload = onDownload
        self.onCancel = onCancel
    }

    public var body: some View {
        Button {
            switch state {
            case .notDownloaded, .failed:
                onDownload()
            case .downloading, .pending:
                onCancel()
            case .paused:
                onDownload() // Resume
            case .completed:
                break // Already downloaded
            }
        } label: {
            Group {
                switch state {
                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                case .pending:
                    Image(systemName: "clock")
                        .foregroundStyle(.orange)
                case let .downloading(progress):
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 22, height: 22)
                case .paused:
                    Image(systemName: "arrow.down.circle.dotted")
                        .foregroundStyle(.orange)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
            .font(.title3)
        }
        .buttonStyle(.plain)
        .disabled(state == .completed)
    }
}

// MARK: - Episode Detail Sheet

/// Sheet showing episode details with play and download options
struct EpisodeDetailSheet: View {
    let episode: MediaItem
    let imageURL: URL?
    let downloadState: DownloadButtonState
    let onPlay: () -> Void
    let onDownload: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Episode thumbnail
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "play.rectangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Episode title
                    VStack(alignment: .leading, spacing: 4) {
                        if let seriesName = episode.seriesName {
                            Text(seriesName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text(episodeTitle)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 12) {
                            if let seasonNumber = episode.parentIndexNumber {
                                Text("Season \(seasonNumber)")
                            }
                            if let runtime = episode.formattedRuntime {
                                Text(runtime)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: onPlay) {
                            HStack {
                                Image(systemName: hasProgress ? "play.fill" : "play.fill")
                                Text(hasProgress ? "Resume" : "Play")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: onDownload) {
                            HStack {
                                downloadIcon
                                Text(downloadText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(downloadState == .completed || downloadState == .pending)
                    }

                    // Overview
                    if let overview = episode.overview {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
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

    private var episodeTitle: String {
        if let episodeNumber = episode.indexNumber {
            return "E\(episodeNumber): \(episode.name)"
        }
        return episode.name
    }

    private var hasProgress: Bool {
        guard let ticks = episode.userData?.playbackPositionTicks else { return false }
        return ticks > 0
    }

    @ViewBuilder
    private var downloadIcon: some View {
        switch downloadState {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
        case .pending:
            Image(systemName: "clock")
        case .downloading:
            Image(systemName: "stop.circle")
        case .paused:
            Image(systemName: "arrow.down.circle.dotted")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle")
        }
    }

    private var downloadText: String {
        switch downloadState {
        case .notDownloaded:
            "Download"
        case .pending:
            "Pending"
        case .downloading:
            "Downloading"
        case .paused:
            "Resume"
        case .completed:
            "Downloaded"
        case .failed:
            "Retry"
        }
    }
}
