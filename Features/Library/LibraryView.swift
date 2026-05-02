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
    @State private var selectedItemForPlayback: MediaItem?

    init(appState: AppState, onboardingManager: OnboardingManager) {
        self.appState = appState
        self.onboardingManager = onboardingManager
        _viewModel = StateObject(wrappedValue: LibraryViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading, viewModel.mediaItems.isEmpty, viewModel.continueWatching.isEmpty {
                    LoadingView(message: "Loading library...")
                } else if let error = viewModel.errorMessage, viewModel.mediaItems.isEmpty {
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
            .toolbar { toolbarContent }
        }
        .task { await viewModel.loadInitialData() }
        .onDisappear { viewModel.cancelAllTasks() }
        .onChange(of: appState.activeServerID) {
            viewModel.cancelAllTasks()
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { ServerSwitcherButton() }
        ToolbarItem(placement: .topBarTrailing) { filterMenu }
        ToolbarItem(placement: .topBarTrailing) { refreshButton }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(LibraryViewModel.MediaTypeFilter.allCases, id: \.self) { filter in
                Button {
                    viewModel.selectedMediaType = filter
                    Task { await viewModel.filterChanged() }
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if viewModel.selectedMediaType == filter { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var refreshButton: some View {
        Button { Task { await viewModel.refresh() } } label: {
            Image(systemName: "arrow.clockwise")
        }
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
                if viewModel.isLoadingContinueWatching {
                    SkeletonCardRow(title: "Continue Watching", cardCount: 4, cardWidth: 140)
                } else if !viewModel.continueWatching.isEmpty {
                    continueWatchingSection
                }
                if viewModel.isLoadingLatestItems {
                    SkeletonCardRow(title: "Recently Added", cardCount: 5, cardWidth: 140)
                } else if !viewModel.latestItems.isEmpty {
                    latestItemsSection
                } else if viewModel.hasLoadedLatestItems {
                    recentlyAddedEmptySection
                }
                if !viewModel.libraries.isEmpty { librariesSection }
                if viewModel.selectedLibrary != nil || viewModel.selectedMediaType != .all {
                    mediaGridSection
                }
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

    private var continueWatchingSection: some View {
        MediaCardRow(title: "Continue Watching") {
            ForEach(viewModel.continueWatching) { item in
                continueWatchingCard(for: item)
            }
        }
    }

    private func continueWatchingCard(for item: MediaItem) -> some View {
        Button { selectedItemForPlayback = item } label: {
            MediaCard(
                title: item.name,
                subtitle: item.seriesName ?? item.formattedRuntime,
                imageURL: viewModel.imageURL(for: item)
            )
            .frame(width: 140)
            .overlay(alignment: .bottomTrailing) { playOverlay }
            .overlay(alignment: .bottom) { progressOverlay(for: item) }
        }
        .buttonStyle(.plain)
        .mediaContextMenu(
            config: contextMenuConfig(for: item, canPlay: true, showDetails: true),
            actions: contextMenuActions(for: item, canPlay: true)
        )
    }

    private var playOverlay: some View {
        Image(systemName: "play.circle.fill").font(.title)
            .foregroundStyle(.white).shadow(radius: 2).padding(8)
    }

    @ViewBuilder
    private func progressOverlay(for item: MediaItem) -> some View {
        if let percentage = item.playedPercentage ?? progressPercentage(for: item) {
            GeometryReader { geometry in
                Rectangle().fill(Color.accentColor)
                    .frame(width: geometry.size.width * (percentage / 100.0), height: 3)
            }.frame(height: 3)
        }
    }

    private func progressPercentage(for item: MediaItem) -> Double? {
        guard let positionTicks = item.userData?.playbackPositionTicks,
              let durationTicks = item.runTimeTicks, durationTicks > 0 else { return nil }
        return Double(positionTicks) / Double(durationTicks) * 100.0
    }

    private var latestItemsSection: some View {
        MediaCardRow(title: "Recently Added") {
            ForEach(viewModel.latestItems) { item in
                NavigationLink(value: item) {
                    MediaCard(
                        title: item.name,
                        subtitle: item.year.map { String($0) },
                        imageURL: viewModel.imageURL(for: item)
                    ).frame(width: 140)
                }
                .buttonStyle(.plain)
                .mediaContextMenu(
                    config: contextMenuConfig(for: item, canPlay: item.isPlayable, showDetails: false),
                    actions: contextMenuActions(for: item, canPlay: item.isPlayable)
                )
            }
        }
    }

    private var recentlyAddedEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added").font(.title2).fontWeight(.bold).padding(.horizontal)
            SectionEmptyView(message: "No recent additions", systemImage: "film.stack")
        }
    }

    private var librariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Libraries").font(.title2).fontWeight(.bold).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.libraries) { library in
                        Button { Task { await viewModel.selectLibrary(library) } } label: {
                            libraryCard(library)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }
        }
    }

    private func libraryCard(_ library: Library) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                .frame(width: 160, height: 90)
                .overlay {
                    Image(systemName: libraryIcon(for: library.collectionType)).font(.title)
                        .foregroundStyle(.secondary)
                }
            Text(library.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
        }
    }

    private func libraryIcon(for type: Library.CollectionType?) -> String {
        switch type {
        case .movies: "film"
        case .tvshows: "tv"
        case .music: "music.note"
        case .books: "book"
        default: "folder"
        }
    }

    private var mediaGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            mediaGridHeader
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                ForEach(viewModel.mediaItems) { item in
                    NavigationLink(value: item) {
                        MediaCard(
                            title: item.name,
                            subtitle: item.year.map { String($0) },
                            imageURL: viewModel.imageURL(for: item),
                            contextMenuConfig: contextMenuConfig(
                                for: item,
                                canPlay: item.isPlayable,
                                showDetails: false
                            ),
                            contextMenuActions: contextMenuActions(for: item, canPlay: item.isPlayable)
                        ).onAppear { Task { await viewModel.loadMoreItemsIfNeeded(currentItem: item) } }
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal)
            if viewModel.isLoadingMore {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            }
        }
    }

    private var mediaGridHeader: some View {
        HStack {
            Text(viewModel.selectedLibrary?.name ?? viewModel.selectedMediaType.rawValue)
                .font(.title2).fontWeight(.bold)
            Spacer()
            if viewModel.selectedLibrary != nil {
                Button("Clear") { Task { await viewModel.selectLibrary(nil) } }.font(.subheadline)
            }
        }.padding(.horizontal)
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
