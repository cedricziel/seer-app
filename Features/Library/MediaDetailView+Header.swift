import JellyfinClient
import SeerUI
import SwiftUI

// MARK: - Header Section

extension MediaDetailView {
    #if os(tvOS)
        private static let tvHeadHeight: CGFloat = 756
    #endif

    /// Title, metadata and action row above the content. Overlaps the
    /// backdrop's poster on iOS/iPadOS; on tvOS renders the full-bleed
    /// backdrop head with everything overlaid bottom-left.
    var headerSection: some View {
        #if os(tvOS)
            tvHeaderSection
        #else
            posterHeaderSection
        #endif
    }

    #if !os(tvOS)
        private var posterHeaderSection: some View {
            HStack(alignment: .top, spacing: 16) {
                PosterImage(url: viewModel.imageURL(for: item), cornerRadius: 8)
                    .frame(width: 100)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title2.bold())

                    if let originalTitle = item.originalTitle, originalTitle != item.name {
                        Text(originalTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    metadataLine()
                    ratingRow(pillFill: .detailPillFill, textColor: .primary)
                }
            }
            .padding(.top, -56)
        }
    #endif

    #if os(tvOS)
        private var tvHeaderSection: some View {
            ZStack(alignment: .bottomLeading) {
                BackdropImage(
                    url: viewModel.imageURL(for: item, type: .backdrop),
                    height: Self.tvHeadHeight
                )
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
                Text(item.name)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)

                metadataLine(color: .white.opacity(0.85))
                ratingRow(pillFill: .white.opacity(0.25), textColor: .white)

                if source == .library, item.type == .movie || item.type == .episode {
                    playButton
                }
            }
            .padding(64)
        }
    #endif

    // MARK: - Shared metadata

    /// "YEAR · DURATION" line, e.g. "2024 · 2 hr 8 min".
    private func metadataLine(color: Color = .secondary) -> some View {
        let parts = [item.year.map(String.init), item.formattedDurationLong].compactMap(\.self)
        return Text(parts.joined(separator: " · "))
            .font(.subheadline)
            .foregroundStyle(color)
    }

    /// Official-rating pill, star + community rating, and a "Watched" label
    /// when the (possibly detailed) item has been played.
    private func ratingRow(pillFill: Color, textColor: Color) -> some View {
        HStack(spacing: 12) {
            if let officialRating = item.officialRating {
                Text(officialRating)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pillFill)
                    .foregroundStyle(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if let rating = item.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundStyle(textColor)
            }

            if displayItem.userData?.played == true {
                watchedLabel
            }
        }
    }

    private var watchedLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
            Text("Watched")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.green)
    }

    // MARK: - Play Button

    var playButton: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if hasProgress {
                progressCaption
            }
        }
    }

    private var progressCaption: some View {
        VStack(alignment: .trailing, spacing: 4) {
            WatchProgressIndicator(
                positionTicks: displayItem.userData?.playbackPositionTicks,
                durationTicks: displayItem.runTimeTicks,
                height: 3
            )
            .frame(height: 3)

            if let remaining = displayItem.remainingTimeText {
                Text(remaining)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
}

// MARK: - Cross-platform colors

private extension Color {
    static var detailPillFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}
