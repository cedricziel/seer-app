import JellyfinClient
import SeerUI
import SwiftUI

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
                        .disabled(
                            downloadState == .completed || downloadState == .pending
                                || downloadState == .waitingForWiFi
                        )
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
        case .waitingForWiFi:
            Image(systemName: "wifi.exclamationmark")
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
        case .waitingForWiFi:
            "Waiting for WiFi"
        case .completed:
            "Downloaded"
        case .failed:
            "Retry"
        }
    }
}
