import JellyfinClient
import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

/// Navigation value for the pushed library grid screen. `.library` shows a
/// single library's items; `.recentlyAdded` shows the cross-library
/// "Recently Added" feed (all libraries, sorted by date added by default).
enum LibraryGridDestination: Hashable {
    case library(Library)
    case recentlyAdded
}

/// Full-screen grid of media items for a library or the cross-library
/// "Recently Added" feed, with sort and filter controls and paging.
///
/// Owns its own `LibraryViewModel` instance (constructed from the shared
/// `AppState`, matching how `LibraryView`'s own content view builds its
/// view model) rather than being handed the Library home screen's instance.
/// Both screens mutate core selection/filter state on this view model
/// (`selectedLibrary`, `selectedMediaType`, `watchStatusFilter`,
/// `isRecentlyAddedFeed`) as part of normal navigation, so sharing one
/// instance between them would let popping this screen silently corrupt
/// Library home's own toolbar filter and currently-selected library.
///
/// On regular width, `selectedItemID` lets a caller route grid taps into a
/// `LibraryDetailColumn`-style detail pane (§5) instead of always pushing
/// `MediaDetailView` onto this screen's own `NavigationStack`. Passing it
/// resolves the item purely by id, so the receiving detail column falls
/// back to a network fetch (`LibraryViewModel.getItemDetails(id:)`) rather
/// than an instant cache hit when it's driven by a different
/// `LibraryViewModel` instance than the one that populated this grid — the
/// two instances intentionally don't share `mediaItems` for the reason
/// above. `LibraryView`'s own `navigationDestination(for:
/// LibraryGridDestination.self)` still needs to thread its detail column's
/// selection binding through to actually engage that pane; that callsite
/// change is out of scope for this file.
struct LibraryGridView: View {
    let destination: LibraryGridDestination
    let appState: AppState
    /// Regular-width detail-pane selection, supplied by a caller that wants
    /// grid taps routed to its own `LibraryDetailColumn` instead of pushed
    /// onto this screen's `NavigationStack`. `nil` (the default) preserves
    /// today's push-only behavior on every width.
    let selectedItemID: Binding<MediaItem.ID?>?
    @StateObject private var viewModel: LibraryViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedItemForPlayback: MediaItem?

    init(destination: LibraryGridDestination, appState: AppState, selectedItemID: Binding<MediaItem.ID?>? = nil) {
        self.destination = destination
        self.appState = appState
        self.selectedItemID = selectedItemID
        _viewModel = StateObject(wrappedValue: LibraryViewModel(appState: appState))
    }

    private var title: String {
        switch destination {
        case let .library(library): library.name
        case .recentlyAdded: "Recently Added"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerRow
                filterBar
                gridSection
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .task { await enterDestination() }
            .fullScreenCover(item: $selectedItemForPlayback) { item in
                VideoPlayerView(
                    item: item,
                    appState: appState,
                    startPositionTicks: item.userData?.playbackPositionTicks ?? 0,
                    onPiPStart: { selectedItemForPlayback = nil }
                )
            }
    }

    private func enterDestination() async {
        switch destination {
        case let .library(library):
            // This screen's filter bar exposes Unwatched/Favorites for
            // library mode, not the media-type capsules — reset any
            // leftover media-type filter left behind by `.recentlyAdded` on
            // this view model's own previous entry so it can't silently
            // restrict this fetch.
            viewModel.isRecentlyAddedFeed = false
            viewModel.selectedMediaType = .all
            await viewModel.selectLibrary(library)
        case .recentlyAdded:
            // Mirror that reset in the other direction: this mode exposes
            // All/Movies/TV Shows, not Unwatched/Favorites, so clear any
            // watch-status filter left behind by library mode.
            viewModel.isRecentlyAddedFeed = true
            viewModel.watchStatusFilter = .all
            await viewModel.selectLibrary(nil)
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        if let count = viewModel.totalItemCount {
            Text("\(count) titles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sortMenu
                switch destination {
                case .library:
                    ForEach(LibraryViewModel.WatchStatusFilter.allCases, id: \.self) { filter in
                        filterCapsule(
                            label: filter.rawValue,
                            isSelected: viewModel.watchStatusFilter == filter
                        ) {
                            viewModel.watchStatusFilter = filter
                            Task { await viewModel.filterChanged() }
                        }
                    }
                case .recentlyAdded:
                    ForEach(LibraryViewModel.MediaTypeFilter.allCases, id: \.self) { filter in
                        filterCapsule(
                            label: filter.rawValue,
                            isSelected: viewModel.selectedMediaType == filter
                        ) {
                            viewModel.selectedMediaType = filter
                            Task { await viewModel.filterChanged() }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                    Task { await viewModel.filterChanged() }
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.sortOption.rawValue)
                Image(systemName: "chevron.down")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.libraryGridFilterFill)
            .clipShape(Capsule())
        }
    }

    private func filterCapsule(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(isSelected ? Color.primary : Color.libraryGridFilterFill)
                .foregroundStyle(isSelected ? Color.libraryGridSelectedLabel(for: colorScheme) : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var gridSection: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading, viewModel.mediaItems.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if let error = viewModel.errorMessage, viewModel.mediaItems.isEmpty {
                SectionEmptyView(message: error, systemImage: "exclamationmark.triangle")
            } else if viewModel.mediaItems.isEmpty {
                SectionEmptyView(message: "No titles match these filters", systemImage: "film.stack")
            }
            LazyVGrid(
                columns: mediaGridColumns(horizontalSizeClass: horizontalSizeClass),
                spacing: 16
            ) {
                ForEach(viewModel.mediaItems) { item in
                    gridLink(for: item)
                        .onAppear { Task { await viewModel.loadMoreItemsIfNeeded(currentItem: item) } }
                }
            }
            .padding(.horizontal)
            if viewModel.isLoadingMore {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            }
        }
    }

    /// Routes to the caller-supplied `selectedItemID` on regular width when
    /// one was provided, otherwise pushes `MediaDetailView` via the
    /// `MediaItem` `navigationDestination` declared by whichever
    /// `NavigationStack` hosts this screen.
    @ViewBuilder
    private func gridLink(for item: MediaItem) -> some View {
        if let selectedItemID, horizontalSizeClass == .regular {
            Button {
                selectedItemID.wrappedValue = item.id
            } label: {
                gridCell(for: item)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: item) {
                gridCell(for: item)
            }
            .buttonStyle(.plain)
        }
    }

    private func gridCell(for item: MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            MediaCard(
                title: item.name,
                subtitle: subtitle(for: item),
                imageURL: viewModel.imageURL(for: item),
                contextMenuConfig: contextMenuConfig(for: item),
                contextMenuActions: contextMenuActions(for: item)
            )
            if item.userData?.played == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white, .green)
                    .padding(6)
            }
        }
    }

    // MARK: - Context Menu Helpers

    private func contextMenuConfig(for item: MediaItem) -> MediaContextMenuConfig {
        MediaContextMenuConfig(
            canPlay: item.isPlayable,
            canDownload: false,
            isDownloaded: false,
            isWatched: item.userData?.played == true,
            showDetailsOption: false
        )
    }

    private func contextMenuActions(for item: MediaItem) -> MediaContextMenuActions {
        MediaContextMenuActions(
            onPlay: item.isPlayable ? { selectedItemForPlayback = item } : nil,
            onToggleWatched: { watched in Task { try? await viewModel.markAsWatched(item, watched: watched) } }
        )
    }

    private func subtitle(for item: MediaItem) -> String? {
        let year = item.year.map { String($0) }
        guard case .recentlyAdded = destination else { return year }
        let typeSuffix = switch item.type {
        case .movie: " · Movie"
        case .series: " · Series"
        default: ""
        }
        guard let year else { return nil }
        return year + typeSuffix
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var libraryGridFilterFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }

    /// Label color on a selected (label-colored) capsule: the background color,
    /// so the pair stays inverted in both light and dark appearance.
    static func libraryGridSelectedLabel(for colorScheme: ColorScheme) -> Color {
        #if os(iOS)
            _ = colorScheme
            return Color(uiColor: .systemBackground)
        #else
            return colorScheme == .dark ? Color.black : Color.white
        #endif
    }
}
