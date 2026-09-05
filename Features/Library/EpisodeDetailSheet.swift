import JellyfinClient
import SeerUI
import SwiftUI

// MARK: - Episode Detail Sheet

/// Episode details with play and download options. Presented as a `.sheet`
/// on iOS/iPadOS; on tvOS the same episode is instead pushed onto the
/// existing navigation stack with a full-bleed backdrop head (matching
/// `MediaDetailView`'s tvOS head treatment: backdrop filling ~70% of the
/// screen, a bottom scrim, and the title/meta/actions overlaid bottom-left,
/// with no poster/thumbnail card), so its own dismiss chrome (wrapping
/// `NavigationStack` + "Done" button) is skipped there.
struct EpisodeDetailSheet: View {
    let episode: MediaItem
    let imageURL: URL?
    let downloadState: DownloadButtonState
    let onPlay: () -> Void
    let onDownload: () -> Void

    #if os(tvOS)
        private static let tvHeadHeight: CGFloat = 756
    #else
        @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        #if os(tvOS)
            tvContent
        #else
            NavigationStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
            }
        #endif
    }

    #if !os(tvOS)
        private var content: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    thumbnail
                    header
                    actionButtons

                    if let overview = episode.overview {
                        overviewSection(overview)
                    }

                    Spacer()
                }
                .padding()
            }
        }

        private var thumbnail: some View {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.episodeDetailSubtleFill)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 4) {
                if let seasonLabel {
                    Text(seasonLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(episodeTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                if let metaText {
                    metaText
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    #endif

    #if os(tvOS)
        private var tvContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    tvHeadSection

                    if let overview = episode.overview {
                        overviewSection(overview)
                            .padding(64)
                    }
                }
            }
        }

        /// Full-bleed backdrop head filling ~70% of the screen, with the
        /// season label, "E4: Title" (64pt bold), meta row and action
        /// buttons overlaid bottom-left. No poster/thumbnail card, per the
        /// tvOS design spec.
        private var tvHeadSection: some View {
            ZStack(alignment: .bottomLeading) {
                BackdropImage(url: imageURL, height: Self.tvHeadHeight)
                tvLeftScrim
                tvBottomScrim
                tvOverlayContent
            }
            .frame(height: Self.tvHeadHeight)
        }

        private var tvLeftScrim: some View {
            LinearGradient(
                colors: [Color.black.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        /// Fades the backdrop into the app's background color at the bottom
        /// edge, so the full-bleed head transitions smoothly into the
        /// content below.
        private var tvBottomScrim: some View {
            LinearGradient(
                colors: [.clear, Color.black],
                startPoint: .center,
                endPoint: .bottom
            )
        }

        private var tvOverlayContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let seasonLabel {
                    Text(seasonLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(episodeTitle)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)

                if let metaText {
                    metaText
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                actionButtons
            }
            .padding(64)
        }
    #endif

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
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

            Button(action: onDownload) {
                HStack {
                    downloadIcon
                    Text(downloadText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.episodeDetailSubtleFill)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(
                downloadState == .completed || downloadState == .pending
                    || downloadState == .waitingForWiFi
            )
        }
    }

    /// Season name for the secondary line above the title, e.g. "Season 2".
    /// Falls back to "Season \(parentIndexNumber)" when `seasonName` is
    /// unavailable, and is omitted entirely when neither is known.
    private var seasonLabel: String? {
        if let seasonName = episode.seasonName, !seasonName.isEmpty {
            return seasonName
        }
        if let seasonNumber = episode.parentIndexNumber {
            return "Season \(seasonNumber)"
        }
        return nil
    }

    private var episodeTitle: String {
        if let episodeNumber = episode.indexNumber {
            return "E\(episodeNumber): \(episode.name)"
        }
        return episode.name
    }

    /// Meta row combining duration, air date and remaining time, e.g.
    /// "46 min · Aired 12 Feb 2024 · 21 min left" with the remaining-time
    /// portion rendered in the accent color. `nil` when none apply.
    private var metaText: Text? {
        var segments: [Text] = []
        if let duration = episode.formattedDurationLong ?? episode.formattedRuntime {
            segments.append(Text(duration))
        }
        if let premiereDate = episode.premiereDate {
            segments.append(Text("Aired \(premiereDate.formatted(date: .medium, time: .omitted))"))
        }
        if let remaining = episode.remainingTimeText {
            segments.append(Text(remaining).foregroundColor(Color.accentColor))
        }

        guard let first = segments.first else { return nil }
        return segments.dropFirst().reduce(first) { $0 + Text(" · ") + $1 }
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

// MARK: - Cross-platform colors

private extension Color {
    static var episodeDetailSubtleFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.15)
        #endif
    }
}
