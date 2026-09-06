import Kingfisher
import SeerUI
import SwiftUI

/// Full-width 16:9 "up next" card for the first Continue Watching item.
///
/// Takes only plain, precomputed data (no `MediaItem`, `DownloadManager` or
/// `AppState`) so the caller stays in charge of fetching images, formatting
/// captions/remaining-time text, and resolving download state.
struct ContinueWatchingHeroCard: View {
    /// Uppercased "SERIES · S2 · E4" style caption. Omitted when nil/empty.
    let caption: String?
    let title: String
    /// Remaining-time text (e.g. "1 hr 12 min left"), overridden by the
    /// offline-dimming rule below when applicable.
    let subtitle: String?
    let imageURL: URL?
    /// Watch progress between 0 and 1. Hidden when nil or <= 0.
    let progress: Double?
    let isDownloaded: Bool
    /// True while the app is showing cached/offline data — engages the
    /// dimming + badge rule for this card.
    let showOfflineDimming: Bool
    let onResume: () -> Void
    var contextMenuConfig: MediaContextMenuConfig?
    var contextMenuActions: MediaContextMenuActions?

    private var isDimmed: Bool {
        showOfflineDimming && !isDownloaded
    }

    private var showDownloadedPill: Bool {
        showOfflineDimming && isDownloaded
    }

    private var displaySubtitle: String? {
        isDimmed ? "Not downloaded" : subtitle
    }

    var body: some View {
        backdrop
            .overlay(scrim)
            .overlay(alignment: .bottomLeading) { captionBlock }
            .overlay(alignment: .bottomTrailing) { resumeButton.padding(16) }
            .overlay(alignment: .topLeading) { downloadedPillIfNeeded }
            .overlay(alignment: .bottom) { progressBar }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
            .opacity(isDimmed ? 0.5 : 1)
            .modifier(OptionalContinueWatchingContextMenu(config: contextMenuConfig, actions: contextMenuActions))
    }

    private var backdrop: some View {
        GeometryReader { geometry in
            KFImage(imageURL)
                .placeholder { Rectangle().fill(Color.continueWatchingFill) }
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    private var scrim: some View {
        LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
    }

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption, !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let displaySubtitle, !displaySubtitle.isEmpty {
                Text(displaySubtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(16)
    }

    private var resumeButton: some View {
        Button(action: onResume) {
            Label("Resume", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
        .disabled(isDimmed)
    }

    @ViewBuilder
    private var downloadedPillIfNeeded: some View {
        if showDownloadedPill {
            Text("Downloaded")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green))
                .padding(12)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress, progress > 0 {
            WatchProgressIndicator(progress: progress, height: 3, backgroundColor: .white.opacity(0.3))
        }
    }
}

/// 180×101 (iOS) / 405×228 (tvOS) landscape card for the remaining
/// Continue Watching items.
struct ContinueWatchingLandscapeCard: View {
    let title: String
    let subtitle: String?
    let imageURL: URL?
    /// Watch progress between 0 and 1. Hidden when nil or <= 0.
    let progress: Double?
    let isDownloaded: Bool
    let showOfflineDimming: Bool
    var contextMenuConfig: MediaContextMenuConfig?
    var contextMenuActions: MediaContextMenuActions?

    #if os(tvOS)
        private static let cardSize = CGSize(width: 405, height: 228)
        private static let progressHeight: CGFloat = 6
    #else
        private static let cardSize = CGSize(width: 180, height: 101)
        private static let progressHeight: CGFloat = 3
    #endif

    private var isDimmed: Bool {
        showOfflineDimming && !isDownloaded
    }

    private var showDownloadBadge: Bool {
        showOfflineDimming && isDownloaded
    }

    private var displaySubtitle: String? {
        isDimmed ? "Not downloaded" : subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let displaySubtitle, !displaySubtitle.isEmpty {
                Text(displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: Self.cardSize.width, alignment: .leading)
        .opacity(isDimmed ? 0.5 : 1)
        .modifier(OptionalContinueWatchingContextMenu(config: contextMenuConfig, actions: contextMenuActions))
    }

    private var thumbnail: some View {
        image
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .watchProgress(progress, height: Self.progressHeight)
            .overlay(alignment: .bottomTrailing) { playGlyph }
            .overlay(alignment: .topTrailing) { downloadBadgeIfNeeded }
    }

    private var image: some View {
        KFImage(imageURL)
            .placeholder {
                Rectangle().fill(Color.continueWatchingFill).overlay {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    private var playGlyph: some View {
        Image(systemName: "play.circle.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .shadow(radius: 2)
            .padding(6)
    }

    @ViewBuilder
    private var downloadBadgeIfNeeded: some View {
        if showDownloadBadge {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .padding(6)
        }
    }
}

/// Applies `.mediaContextMenu` only when both a config and actions are
/// supplied, matching `MediaCard`'s optional-context-menu pattern.
private struct OptionalContinueWatchingContextMenu: ViewModifier {
    let config: MediaContextMenuConfig?
    let actions: MediaContextMenuActions?

    func body(content: Content) -> some View {
        if let config, let actions {
            content.mediaContextMenu(config: config, actions: actions)
        } else {
            content
        }
    }
}

private extension Color {
    static var continueWatchingFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ContinueWatchingHeroCard(
                caption: "Series · S2 · E4",
                title: "Sample Title",
                subtitle: "1 hr 12 min left",
                imageURL: nil,
                progress: 0.4,
                isDownloaded: false,
                showOfflineDimming: false,
                onResume: {}
            )
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ContinueWatchingLandscapeCard(
                        title: "Another Title",
                        subtitle: "21 min left",
                        imageURL: nil,
                        progress: 0.7,
                        isDownloaded: true,
                        showOfflineDimming: true
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
