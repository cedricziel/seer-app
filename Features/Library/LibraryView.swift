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
    /// Read at this level — *outside* the `NavigationSplitView` below — on
    /// purpose. The split view hands its sidebar column a compact
    /// horizontal size class regardless of device, so any view inside the
    /// column cannot tell "iPhone" from "iPad content column" on its own.
    /// `isSplitLayout` is derived here once and passed down explicitly.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedItemForPlayback: MediaItem?
    @State private var path = NavigationPath()
    /// Detail-column selection when the split view shows both columns
    /// (iPad / Mac Designed for iPad). On compact width the split view is
    /// collapsed and navigation pushes `MediaDetailView` onto `path`
    /// instead, so this stays `nil` there. Cleared whenever a grid screen
    /// is pushed so the detail pane never shows an item from a previous
    /// library.
    @State private var selectedItem: MediaItem?

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

    /// Whether the split view currently shows its detail column alongside
    /// the home content, so item taps should *select* into that column
    /// rather than push. Always `false` on tvOS, which uses a plain stack.
    private var isSplitLayout: Bool {
        #if os(tvOS)
            return false
        #else
            return horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        rootContainer
            .task { await viewModel.loadInitialData() }
            .onDisappear { viewModel.cancelAllTasks() }
            .onChange(of: appState.activeServerID) {
                path = NavigationPath()
                selectedItem = nil
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

    // MARK: - Navigation containers

    /// One container per platform, kept stable across size-class changes:
    ///
    /// - tvOS: a plain `NavigationStack`.
    /// - iOS / iPadOS / Mac (Designed for iPad): a two-column
    ///   `NavigationSplitView`. On regular width the home content (with its
    ///   own `NavigationStack` for the grid and detail pushes) sits in the
    ///   leading column and `LibraryDetailColumn` in the trailing one; on
    ///   compact width the split view collapses to that leading stack by
    ///   itself, so iPhone and iPad Split View / Slide Over never swap
    ///   containers mid-session.
    @ViewBuilder
    private var rootContainer: some View {
        #if os(tvOS)
            homeStack
        #else
            NavigationSplitView(columnVisibility: .constant(.all)) {
                homeStack
                    // Keep the content column within a sidebar-style width
                    // range so the detail column always has room, including
                    // on the narrowest current iPad (mini, 744pt portrait).
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 600)
                    // The home content is the primary surface, not a
                    // collapsible sidebar; the tab sidebar already provides
                    // that role on iPad.
                    .toolbar(removing: .sidebarToggle)
            } detail: {
                LibraryDetailColumn(selectedItem: selectedItem, viewModel: viewModel)
            }
            .navigationSplitViewStyle(.balanced)
        #endif
    }

    private var homeStack: some View {
        NavigationStack(path: $path) {
            homeRoot
        }
    }

    /// Root screen of the home stack: loading/error switch, the toolbar,
    /// and the push destinations. Everything here is *inside* the
    /// `NavigationStack` so the toolbar items land in its navigation bar.
    private var homeRoot: some View {
        Group {
            if viewModel.isLoading, viewModel.libraries.isEmpty, viewModel.continueWatching.isEmpty {
                LoadingView(message: "Loading library...")
            } else if let error = hostAwareErrorMessage, viewModel.libraries.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.refresh() }
                }
            } else {
                contentView
            }
        }
        .navigationTitle("Library")
        .toolbar { toolbarContent }
        .navigationDestination(for: MediaItem.self) { item in
            MediaDetailView(item: item, source: .library, viewModel: viewModel)
        }
        .navigationDestination(for: MediaItem.Person.self) { person in
            PersonDetailView(person: person, appState: appState)
        }
        .navigationDestination(for: LibraryGridDestination.self) { destination in
            LibraryGridView(
                destination: destination,
                appState: appState,
                selectedItem: isSplitLayout ? $selectedItem : nil
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

    /// Pushes a grid screen and drops any detail-column selection, so the
    /// detail pane doesn't keep showing an item from the previous context.
    private func openGrid(_ destination: LibraryGridDestination) {
        selectedItem = nil
        path.append(destination)
    }

    @ViewBuilder
    private var chipRow: some View {
        if !viewModel.libraries.isEmpty {
            LibraryChipRow(libraries: viewModel.libraries) { library in
                openGrid(.library(library))
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
            #if !os(tvOS)
                SkeletonHeroRow().padding(.horizontal)
            #endif
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
            isDownloaded: offlineDimmingEnabled ? isItemDownloaded(item) : false,
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
                isDownloaded: offlineDimmingEnabled ? isItemDownloaded(item) : false,
                showOfflineDimming: offlineDimmingEnabled,
                contextMenuConfig: contextMenuConfig(for: item, canPlay: true, showDetails: true),
                contextMenuActions: contextMenuActions(for: item, canPlay: true)
            )
        }
        .buttonStyle(.plain)
        .disabled(offlineDimmingEnabled && !isItemDownloaded(item))
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
                openGrid(.recentlyAdded)
            } label: {
                Text("See All ›").font(.subheadline).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal)
    }

    private func latestItemCard(for item: MediaItem) -> some View {
        let downloaded = offlineDimmingEnabled ? isItemDownloaded(item) : false
        let card = ZStack(alignment: .topTrailing) {
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
        return Group {
            if isSplitLayout {
                // Split layout shows the detail in the trailing column
                // instead of pushing onto `path`.
                Button { selectedItem = item } label: { card }
            } else {
                NavigationLink(value: item) { card }
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
            onToggleWatched: { watched in Task { try? await viewModel.markAsWatched(item, watched: watched) } },
            onShowDetails: { showDetails(for: item) }
        )
    }

    /// Opens `MediaDetailView` for an item whose primary tap does something
    /// else (Continue Watching cards resume playback): into the detail
    /// column when the split view shows one, otherwise pushed onto `path`.
    private func showDetails(for item: MediaItem) {
        if isSplitLayout {
            selectedItem = item
        } else {
            path.append(item)
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
        .environmentObject(OnboardingManager())
}
