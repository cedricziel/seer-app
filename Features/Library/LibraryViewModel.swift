import Foundation
import JellyfinClient
import OfflineSync
import os
import SeerCore
import SwiftData
import SwiftUI

/// View model for the library browsing feature with offline support
@MainActor
public final class LibraryViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.seer.app", category: "LibraryViewModel")

    @Published var libraries: [Library] = []
    @Published var selectedLibrary: Library?
    @Published var mediaItems: [MediaItem] = []
    @Published var continueWatching: [MediaItem] = []
    @Published var latestItems: [MediaItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var isLoadingLatestItems: Bool = false
    @Published var isLoadingContinueWatching: Bool = false
    @Published var hasLoadedLatestItems: Bool = false
    @Published var hasLoadedContinueWatching: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMediaType: MediaTypeFilter = .all
    @Published var isShowingCachedData: Bool = false
    @Published var lastSyncDate: Date?
    @Published var totalItemCount: Int?
    @Published var sortOption: SortOption = .dateAdded
    @Published var watchStatusFilter: WatchStatusFilter = .all
    /// Set by the pushed grid screen when browsing the cross-library
    /// "Recently Added" feed (`selectedLibrary == nil` with no specific
    /// library chosen). Restricts the `.all` media-type filter to
    /// Movies/Series — matching what `getLatestItems` already curates for
    /// the home screen — instead of an unrestricted recursive fetch across
    /// every library, which would otherwise also return Series/Season/
    /// Episode container rows.
    @Published var isRecentlyAddedFeed: Bool = false

    enum MediaTypeFilter: String, CaseIterable {
        case all = "All", movies = "Movies", shows = "TV Shows"
        var jellyfinTypes: [MediaItem.MediaType]? {
            switch self {
            case .all: nil
            case .movies: [.movie]
            case .shows: [.series]
            }
        }

        var cachedMediaTypes: [String]? {
            switch self {
            case .all: nil
            case .movies: ["Movie"]
            case .shows: ["Series"]
            }
        }
    }

    /// Sort field for the library grid screen, mapped onto Jellyfin's
    /// `SortBy`/`SortOrder` query values.
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added", name = "Name", year = "Year", rating = "Rating"

        var jellyfinSortBy: String {
            switch self {
            case .dateAdded: "DateCreated"
            case .name: "SortName"
            case .year: "ProductionYear"
            case .rating: "CommunityRating"
            }
        }

        var jellyfinSortOrder: String {
            switch self {
            case .name: "Ascending"
            case .dateAdded, .year, .rating: "Descending"
            }
        }
    }

    /// Watched/favorite filter for the library grid screen, mapped onto
    /// Jellyfin's `Filters` query value.
    enum WatchStatusFilter: String, CaseIterable {
        case all = "All", unwatched = "Unwatched", favorites = "Favorites"

        var jellyfinFilters: [String]? {
            switch self {
            case .all: nil
            case .unwatched: ["IsUnplayed"]
            case .favorites: ["IsFavorite"]
            }
        }
    }

    /// Item types to request from the server for the current selection. See
    /// `isRecentlyAddedFeed`'s documentation for why `.all` is special-cased
    /// when no library is selected.
    private var effectiveIncludeItemTypes: [MediaItem.MediaType]? {
        guard selectedLibrary == nil, isRecentlyAddedFeed else { return selectedMediaType.jellyfinTypes }
        return selectedMediaType.jellyfinTypes ?? [.movie, .series]
    }

    private var jellyfinService: JellyfinService?
    private var serverURL: URL?
    private let appState: AppState
    private var currentPage: Int = 0
    private let pageSize: Int = 50
    private var hasMoreItems: Bool = true
    private var loadTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var mediaItemSyncService: MediaItemSyncService?
    private var librarySyncService: LibrarySyncService?
    private var serverConfigurationID: UUID?
    private weak var networkMonitor: NetworkMonitor?
    private let dataConverter = CachedDataConverter()

    public init(appState: AppState) {
        self.appState = appState
        setupService()
    }

    public func setupOfflineSync(modelContext: ModelContext, networkMonitor: NetworkMonitor) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor
        mediaItemSyncService = MediaItemSyncService(modelContext: modelContext)
        librarySyncService = LibrarySyncService(modelContext: modelContext)
        serverConfigurationID = appState.activeServer?.id
    }

    private func setupService() {
        guard let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID
        else {
            serverURL = nil
            jellyfinService = nil
            return
        }
        self.serverURL = serverURL
        jellyfinService = JellyfinService(
            serverURL: serverURL, accessToken: accessToken,
            userID: userID, deviceID: appState.jellyfinDeviceID
        )
    }

    /// Rebuild the service and clear server-specific state after the active
    /// server changed. Without this, refreshes keep using the previous
    /// server's client, token and cache scope.
    func serverChanged() {
        cancelAllTasks()
        // Cancelled loads never reach their `isLoading = false`; reset here so
        // the view cannot stay on the loading state for the new server.
        isLoading = false
        isLoadingMore = false
        isLoadingLatestItems = false
        isLoadingContinueWatching = false
        setupService()
        serverConfigurationID = appState.activeServer?.id
        libraries = []
        selectedLibrary = nil
        mediaItems = []
        continueWatching = []
        latestItems = []
        hasLoadedLatestItems = false
        hasLoadedContinueWatching = false
        errorMessage = nil
        currentPage = 0
        hasMoreItems = true
    }

    func loadInitialData() async {
        loadTask?.cancel()
        await loadCachedDataIfAvailable()
        guard jellyfinService != nil else {
            if libraries.isEmpty { errorMessage = "Not connected to Jellyfin" }
            return
        }
        guard networkMonitor?.isConnected ?? true else {
            isShowingCachedData = true
            isLoading = false
            return
        }
        loadTask = Task {
            guard !Task.isCancelled else { return }
            if libraries.isEmpty { isLoading = true }
            errorMessage = nil
            async let lib: Void = loadLibraries()
            async let cont: Void = loadContinueWatching()
            async let lat: Void = loadLatestItems()
            _ = await (lib, cont, lat)
            guard !Task.isCancelled else { return }
            isLoading = false
            isShowingCachedData = false
            lastSyncDate = Date()
        }
        await loadTask?.value
    }

    private func loadCachedDataIfAvailable() async {
        guard let id = serverConfigurationID, let libSync = librarySyncService,
              let itemSync = mediaItemSyncService else { return }
        do {
            let cachedLibs = try libSync.getCachedLibraries(for: id)
            if !cachedLibs.isEmpty {
                libraries = cachedLibs.compactMap { dataConverter.convertToLibrary($0) }
                isShowingCachedData = true
            }
            let cachedCW = try itemSync.getCachedContinueWatching(serverConfigurationID: id)
            if !cachedCW.isEmpty {
                continueWatching = cachedCW.map { dataConverter.convertToMediaItem($0) }
                hasLoadedContinueWatching = true
            }
        } catch { Self.logger.debug("Failed to load cached data: \(error.localizedDescription)") }
    }

    func loadLibraries() async {
        guard let service = jellyfinService, !Task.isCancelled else { return }
        do {
            let result = try await service.getLibraries()
            guard !Task.isCancelled else { return }
            libraries = result
            if let cfg = appState.activeServer {
                try? await librarySyncService?.syncLibraries(serverConfig: cfg, service: service)
            }
        } catch { if !Task.isCancelled, libraries.isEmpty { errorMessage = error.localizedDescription } }
    }

    func loadContinueWatching() async {
        guard let service = jellyfinService, !Task.isCancelled else { return }
        isLoadingContinueWatching = true
        do {
            let result = try await service.getContinueWatching(limit: 10)
            guard !Task.isCancelled else { return }
            continueWatching = result
            if let cfg = appState.activeServer {
                try? await mediaItemSyncService?.syncContinueWatching(serverConfig: cfg, service: service)
            }
        } catch {
            if !Task
                .isCancelled { Self.logger.debug("Failed to load continue watching: \(error.localizedDescription)") }
        }
        hasLoadedContinueWatching = true
        isLoadingContinueWatching = false
    }

    func loadLatestItems() async {
        guard let service = jellyfinService, !Task.isCancelled else { return }
        isLoadingLatestItems = true
        do {
            let result = try await service.getLatestItems(limit: 20)
            guard !Task.isCancelled else { return }
            latestItems = result
            if let cfg = appState.activeServer {
                try? await mediaItemSyncService?.syncLatestItems(serverConfig: cfg, service: service)
            }
        } catch {
            if !Task.isCancelled { Self.logger.debug("Failed to load latest items: \(error.localizedDescription)") }
        }
        hasLoadedLatestItems = true
        isLoadingLatestItems = false
    }

    func selectLibrary(_ library: Library?) async {
        selectedLibrary = library
        currentPage = 0
        hasMoreItems = true
        mediaItems = []
        await loadCachedLibraryItems()
        await loadMediaItems()
    }

    private func loadCachedLibraryItems() async {
        guard let id = serverConfigurationID, let sync = mediaItemSyncService else { return }
        do {
            var items = try sync.getCachedItems(for: selectedLibrary?.id, serverConfigurationID: id)
            if let types = selectedMediaType.cachedMediaTypes {
                items = items.filter { types.contains($0.mediaType) }
            }
            if !items.isEmpty {
                mediaItems = items.map { dataConverter.convertToMediaItem($0) }
                isShowingCachedData = true
            }
        } catch { Self.logger.debug("Failed to load cached library items: \(error.localizedDescription)") }
    }

    func loadMediaItems() async {
        guard let service = jellyfinService, !Task.isCancelled else { return }
        guard networkMonitor?.isConnected ?? true else { isShowingCachedData = true; return }
        isLoading = mediaItems.isEmpty
        errorMessage = nil
        do {
            let response = try await service.getItems(
                parentID: selectedLibrary?.id, includeItemTypes: effectiveIncludeItemTypes,
                sortBy: sortOption.jellyfinSortBy, sortOrder: sortOption.jellyfinSortOrder,
                limit: pageSize, startIndex: currentPage * pageSize,
                filters: watchStatusFilter.jellyfinFilters
            )
            guard !Task.isCancelled else { return }
            mediaItems = response.items
            hasMoreItems = mediaItems.count < response.totalRecordCount
            totalItemCount = selectedLibrary != nil ? response.totalRecordCount : nil
            isShowingCachedData = false
            if let cfg = appState.activeServer, let lib = selectedLibrary, let ctx = modelContext {
                let desc = FetchDescriptor<CachedLibrary>(predicate: #Predicate { $0.id == lib.id })
                if let cachedLib = try? ctx.fetch(desc).first {
                    try? await mediaItemSyncService?.syncLibraryItems(
                        library: cachedLib, serverConfig: cfg, service: service
                    )
                }
            }
        } catch { if !Task.isCancelled, mediaItems.isEmpty { errorMessage = error.localizedDescription } }
        isLoading = false
    }

    func loadMoreItemsIfNeeded(currentItem: MediaItem) async {
        guard hasMoreItems, !isLoadingMore, let last = mediaItems.last, currentItem.id == last.id else { return }
        await loadMoreItems()
    }

    func loadMoreItems() async {
        guard let service = jellyfinService, hasMoreItems, !isLoadingMore,
              networkMonitor?.isConnected ?? true, !Task.isCancelled else { return }
        isLoadingMore = true
        currentPage += 1
        do {
            let response = try await service.getItems(
                parentID: selectedLibrary?.id, includeItemTypes: effectiveIncludeItemTypes,
                sortBy: sortOption.jellyfinSortBy, sortOrder: sortOption.jellyfinSortOrder,
                limit: pageSize, startIndex: currentPage * pageSize,
                filters: watchStatusFilter.jellyfinFilters
            )
            guard !Task.isCancelled else { currentPage -= 1; isLoadingMore = false; return }
            mediaItems.append(contentsOf: response.items)
            hasMoreItems = mediaItems.count < response.totalRecordCount
            totalItemCount = selectedLibrary != nil ? response.totalRecordCount : nil
        } catch {
            currentPage -= 1; if !Task
                .isCancelled { Self.logger.debug("Failed to load more items: \(error.localizedDescription)") }
        }
        isLoadingMore = false
    }

    func filterChanged() async {
        currentPage = 0
        hasMoreItems = true
        mediaItems = []
        await loadCachedLibraryItems()
        await loadMediaItems()
    }

    func refresh() async {
        loadTask?.cancel()
        refreshTask?.cancel()
        refreshTask = Task {
            guard !Task.isCancelled else { return }
            currentPage = 0
            hasMoreItems = true
            hasLoadedLatestItems = false
            hasLoadedContinueWatching = false
            await loadInitialData()
            guard !Task.isCancelled else { return }
            if selectedLibrary != nil || isRecentlyAddedFeed { await loadMediaItems() }
        }
        await refreshTask?.value
    }

    enum ImageType: String { case primary = "Primary", backdrop = "Backdrop", thumb = "Thumb" }

    func imageURL(for item: MediaItem, type: ImageType = .primary) -> URL? {
        serverURL?.appendingPathComponent("Items/\(item.id)/Images/\(type.rawValue)")
    }

    func imageURL(for library: Library) -> URL? {
        serverURL?.appendingPathComponent("Items/\(library.id)/Images/Primary")
    }

    func personImageURL(for person: MediaItem.Person, maxWidth: Int? = 240) -> URL? {
        guard let id = person.id, !id.isEmpty, let serverURL else { return nil }
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(id)/Images/Primary"),
            resolvingAgainstBaseURL: false
        )
        var queryItems: [URLQueryItem] = []
        if let tag = person.imageTag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    /// Fetch full item details including format information (MediaSources)
    func getItemDetails(id: String) async -> MediaItem? {
        guard let service = jellyfinService else { return nil }
        do {
            return try await service.getItem(id: id)
        } catch {
            Self.logger.error("Failed to fetch item details: \(error.localizedDescription)")
            return nil
        }
    }

    /// Mark an item as watched or unwatched
    func markAsWatched(_ item: MediaItem, watched: Bool) async throws {
        guard let service = jellyfinService else { return }

        if watched {
            try await service.markAsPlayed(itemId: item.id)
        } else {
            try await service.markAsUnplayed(itemId: item.id)
        }

        // Refresh to update the UI with new watch status
        await refresh()
    }

    func cancelAllTasks() {
        loadTask?.cancel()
        refreshTask?.cancel()
        loadTask = nil
        refreshTask = nil
    }
}
