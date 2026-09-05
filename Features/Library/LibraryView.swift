import DownloadClient
import JellyfinClient
import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

/// Main library browsing view
struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var onboardingManager: OnboardingManager

    var body: some View {
        LibraryContentView(appState: appState, onboardingManager: onboardingManager)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct LibraryContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var onboardingManager: OnboardingManager
    @StateObject private var viewModel: LibraryViewModel
    @Environment(DownloadManager.self) private var downloadManager: DownloadManager?
    @State private var selectedItemForPlayback: MediaItem?
    @State private var path = NavigationPath()

    #if os(tvOS)
        private let recentlyAddedCardWidth: CGFloat = 196
    #else
        private let recentlyAddedCardWidth: CGFloat = 140
    #endif

    init(appState: AppState, onboardingManager: OnboardingManager) {
        self.appState = appState
        self.onboardingManager = onboardingManager
        _viewModel = StateObject(wrappedValue: LibraryViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading, viewModel.mediaItems.isEmpty, viewModel.continueWatching.isEmpty {
                    LoadingView(message: "Loading library...")
                } else if let error = hostAwareErrorMessage, viewModel.mediaItems.isEmpty {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    contentView
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(item: item, source: .library, viewModel: viewModel)
            }
            .navigationDestination(for: MediaItem.Person.self) { person in
                PersonDetailView(person: person, appState: appState)
            }
            .navigationDestination(for: LibraryGridDestination.self) { destination in
                LibraryGridView(destination: destination, appState: appState)
            }
            .toolbar { toolbarContent }
        }
        .task { await viewModel.loadInitialData() }
        .onDisappear { viewModel.cancelAllTasks() }
        .onChange(of: appState.activeServerID) {
            viewModel.serverChanged()
            Task { await viewModel.refresh() }
        }
        .fullScreenCover(item: $selectedItemForPlayback) { item in
            VideoPlayerView(
                item: item,
                appState: appState,
                startPositionTicks: item.userData?.playbackPositionTicks ?? 0,
                onPiPStart: { selectedItemForPlayback = nil }
            )
        }
    }

    private var hostAwareErrorMessage: String? {
        guard let error = viewModel.errorMessage else { return nil }
        guard let host = appState.activeServer?.jellyfinHost else { return error }
        return "\(error) (\(host))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { ServerSwitcherButton() }
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if viewModel.isShowingCachedData {
                    OfflineBanner(
                        isOffline: true,
                        lastSyncDate: viewModel.lastSyncDate,
                        onRefresh: { Task { await viewModel.refresh() } }
                    )
                    .accessibilityIdentifier("library.offlineBanner")
                }
                if onboardingManager.isFirstLaunchAfterSetup {
                    firstTimeTipSection
                }
                chipRow
                continueWatchingBlock
                recentlyAddedBlock
            }
            .padding(.vertical)
        }
        .refreshable { await viewModel.refresh() }
    }

    private var firstTimeTipSection: some View {
        VStack(spacing: 12) {
            OnboardingTipView(
                title: "Welcome to Your Library",
                description: "Your library is syncing. Explore the Discover tab to find new content while you wait."
            )
            .padding(.horizontal)

            Button {
                onboardingManager.clearFirstLaunchFlag()
            } label: {
                Text("Dismiss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var chipRow: some View {
        if !viewModel.libraries.isEmpty {
            LibraryChipRow(libraries: viewModel.libraries) { library in
                path.append(LibraryGridDestination.library(library))
            }
        }
    }

    // MARK: - Continue Watching

    @ViewBuilder
    private var continueWatchingBlock: some View {
        if viewModel.isLoadingContinueWatching {
            continueWatchingSkeleton
        } else if !viewModel.continueWatching.isEmpty {
            continueWatchingSection
        }
    }

    private var continueWatchingSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continue Watching").font(.title2).fontWeight(.bold).padding(.horizontal)
            SkeletonHeroRow().padding(.horizontal)
            SkeletonLandscapeRow()
        }
    }

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continue Watching").font(.title2).fontWeight(.bold).padding(.horizontal)
            #if os(tvOS)
                landscapeRow(items: Array(viewModel.continueWatching.prefix(4)))
            #else
                if let hero = viewModel.continueWatching.first {
                    heroCard(for: hero).padding(.horizontal)
                }
                let rest = Array(viewModel.continueWatching.dropFirst())
                if !rest.isEmpty { landscapeRow(items: rest) }
            #endif
        }
    }

    private func landscapeRow(items: [MediaItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in landscapeCard(for: item) }
            }
            .padding(.horizontal)
        }
    }

    private func heroCard(for item: MediaItem) -> some View {
        ContinueWatchingHeroCard(
            caption: episodeCaption(for: item),
            title: item.name,
            subtitle: heroSubtitle(for: item),
            imageURL: continueWatchingImageURL(for: item),
            progress: progressFraction(for: item),
            isDownloaded: isItemDownloaded(item),
            showOfflineDimming: offlineDimmingEnabled,
            onResume: { selectedItemForPlayback = item },
            contextMenuConfig: contextMenuConfig(for: item, canPlay: true, showDetails: true),
            contextMenuActions: contextMenuActions(for: item, canPlay: true)
        )
    }

    private func landscapeCard(for item: MediaItem) -> some View {
        Button { selectedItemForPlayback = item } label: {
            ContinueWatchingLandscapeCard(
                title: item.name,
                subtitle: landscapeSubtitle(for: item),
                imageURL: continueWatchingImageURL(for: item),
                progress: progressFraction(for: item),
                isDownloaded: isItemDownloaded(item),
                showOfflineDimming: offlineDimmingEnabled,
                contextMenuConfig: contextMenuConfig(for: item, canPlay: true, showDetails: true),
                contextMenuActions: contextMenuActions(for: item, canPlay: true)
            )
        }
        .buttonStyle(.plain)
    }

    private func continueWatchingImageURL(for item: MediaItem) -> URL? {
        if let backdropTags = item.backdropImageTags, !backdropTags.isEmpty {
            return viewModel.imageURL(for: item, type: .backdrop)
        }
        return viewModel.imageURL(for: item, type: .primary)
    }

    private func progressFraction(for item: MediaItem) -> Double? {
        if let percentage = item.playedPercentage { return percentage / 100.0 }
        guard let positionTicks = item.userData?.playbackPositionTicks,
              let durationTicks = item.runTimeTicks, durationTicks > 0 else { return nil }
        return Double(positionTicks) / Double(durationTicks)
    }

    private func episodeCaption(for item: MediaItem) -> String? {
        guard item.type == .episode else { return nil }
        var parts: [String] = []
        if let seriesName = item.seriesName { parts.append(seriesName) }
        if let season = item.parentIndexNumber { parts.append("S\(season)") }
        if let episode = item.indexNumber { parts.append("E\(episode)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func heroSubtitle(for item: MediaItem) -> String? {
        item.remainingTimeText ?? item.seriesName ?? item.formattedRuntime
    }

    private func landscapeSubtitle(for item: MediaItem) -> String? {
        guard let remaining = item.remainingTimeText else {
            return item.seriesName ?? item.formattedRuntime
        }
        if let caption = episodeCaption(for: item) {
            return "\(caption) · \(remaining)"
        }
        return remaining
    }

    // MARK: - Recently Added

    @ViewBuilder
    private var recentlyAddedBlock: some View {
        if viewModel.isLoadingLatestItems {
            SkeletonCardRow(title: "Recently Added", cardCount: 5, cardWidth: recentlyAddedCardWidth)
        } else if !viewModel.latestItems.isEmpty {
            latestItemsSection
        } else if viewModel.hasLoadedLatestItems {
            recentlyAddedEmptySection
        }
    }

    private var latestItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            latestItemsHeader
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.latestItems) { item in
                        latestItemCard(for: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var latestItemsHeader: some View {
        HStack {
            Text("Recently Added").font(.title2).fontWeight(.bold)
            Spacer()
            Button {
                path.append(LibraryGridDestination.recentlyAdded)
            } label: {
                Text("See All ›").font(.subheadline).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal)
    }

    private func latestItemCard(for item: MediaItem) -> some View {
        let downloaded = isItemDownloaded(item)
        return NavigationLink(value: item) {
            ZStack(alignment: .topTrailing) {
                MediaCard(
                    title: item.name,
                    subtitle: latestItemSubtitle(for: item, downloaded: downloaded),
                    imageURL: viewModel.imageURL(for: item)
                )
                .frame(width: recentlyAddedCardWidth)
                .opacity(offlineDimmingEnabled && !downloaded ? 0.5 : 1)
                if offlineDimmingEnabled, downloaded {
                    downloadedBadge
                }
            }
        }
        .buttonStyle(.plain)
        .mediaContextMenu(
            config: contextMenuConfig(for: item, canPlay: item.isPlayable, showDetails: false),
            actions: contextMenuActions(for: item, canPlay: item.isPlayable)
        )
    }

    private func latestItemSubtitle(for item: MediaItem, downloaded: Bool) -> String? {
        if offlineDimmingEnabled, !downloaded { return "Not downloaded" }
        return item.year.map { String($0) }
    }

    private var downloadedBadge: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.caption)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .green)
            .padding(6)
    }

    private var recentlyAddedEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added").font(.title2).fontWeight(.bold).padding(.horizontal)
            SectionEmptyView(message: "No recent additions", systemImage: "film.stack")
        }
    }

    // MARK: - Download / Offline Helpers

    private var offlineDimmingEnabled: Bool {
        downloadManager != nil && viewModel.isShowingCachedData
    }

    private func isItemDownloaded(_ item: MediaItem) -> Bool {
        guard let downloadManager else { return false }
        return downloadManager.downloadSync(
            forItemID: item.id,
            serverID: appState.activeServerKey ?? "default"
        )?.state == .completed
    }

    // MARK: - Context Menu Helpers

    private func contextMenuConfig(for item: MediaItem, canPlay: Bool, showDetails: Bool) -> MediaContextMenuConfig {
        MediaContextMenuConfig(
            canPlay: canPlay,
            canDownload: false,
            isDownloaded: false,
            isWatched: item.userData?.played == true,
            showDetailsOption: showDetails
        )
    }

    private func contextMenuActions(for item: MediaItem, canPlay: Bool) -> MediaContextMenuActions {
        MediaContextMenuActions(
            onPlay: canPlay ? { selectedItemForPlayback = item } : nil,
            onToggleWatched: { watched in Task { try? await viewModel.markAsWatched(item, watched: watched) } }
        )
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
        .environmentObject(OnboardingManager())
}
