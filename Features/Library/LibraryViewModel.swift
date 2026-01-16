import Foundation
import JellyfinClient
import SeerCore
import SwiftUI

/// View model for the library browsing feature
@MainActor
public final class LibraryViewModel: ObservableObject {
    // MARK: - Published Properties

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

    enum MediaTypeFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case shows = "TV Shows"

        var jellyfinTypes: [MediaItem.MediaType]? {
            switch self {
            case .all: nil
            case .movies: [.movie]
            case .shows: [.series]
            }
        }
    }

    // MARK: - Private Properties

    private var jellyfinService: JellyfinService?
    private var serverURL: URL?
    private let appState: AppState
    private var currentPage: Int = 0
    private let pageSize: Int = 50
    private var hasMoreItems: Bool = true

    // Task tracking for cancellation
    private var loadTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(appState: AppState) {
        self.appState = appState
        setupService()
    }

    private func setupService() {
        guard let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID
        else {
            return
        }

        self.serverURL = serverURL
        jellyfinService = JellyfinService(
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            deviceID: appState.jellyfinDeviceID
        )
    }

    // MARK: - Public Methods

    func loadInitialData() async {
        // Cancel any existing load task
        loadTask?.cancel()

        guard jellyfinService != nil else {
            errorMessage = "Not connected to Jellyfin"
            return
        }

        loadTask = Task {
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil

            // Load data in parallel
            async let librariesTask = loadLibraries()
            async let continueTask = loadContinueWatching()
            async let latestTask = loadLatestItems()

            _ = await (librariesTask, continueTask, latestTask)

            guard !Task.isCancelled else { return }

            isLoading = false
        }

        await loadTask?.value
    }

    func loadLibraries() async {
        guard let service = jellyfinService else { return }
        guard !Task.isCancelled else { return }

        do {
            let result = try await service.getLibraries()
            guard !Task.isCancelled else { return }
            libraries = result
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadContinueWatching() async {
        guard let service = jellyfinService else { return }
        guard !Task.isCancelled else { return }

        isLoadingContinueWatching = true

        do {
            let result = try await service.getContinueWatching(limit: 10)
            guard !Task.isCancelled else { return }
            continueWatching = result
        } catch {
            // Not critical if this fails, but suppress cancellation errors
            if !Task.isCancelled {
                print("Failed to load continue watching: \(error)")
            }
        }

        hasLoadedContinueWatching = true
        isLoadingContinueWatching = false
    }

    func loadLatestItems() async {
        guard let service = jellyfinService else { return }
        guard !Task.isCancelled else { return }

        isLoadingLatestItems = true

        do {
            let result = try await service.getLatestItems(limit: 20)
            guard !Task.isCancelled else { return }
            latestItems = result
        } catch {
            // Suppress cancellation errors
            if !Task.isCancelled {
                print("Failed to load latest items: \(error)")
            }
        }

        hasLoadedLatestItems = true
        isLoadingLatestItems = false
    }

    func selectLibrary(_ library: Library?) async {
        selectedLibrary = library
        currentPage = 0
        hasMoreItems = true
        mediaItems = []

        await loadMediaItems()
    }

    func loadMediaItems() async {
        guard let service = jellyfinService else { return }
        guard !Task.isCancelled else { return }

        isLoading = mediaItems.isEmpty
        errorMessage = nil

        do {
            let response = try await service.getItems(
                parentID: selectedLibrary?.id,
                includeItemTypes: selectedMediaType.jellyfinTypes,
                limit: pageSize,
                startIndex: currentPage * pageSize
            )

            guard !Task.isCancelled else { return }

            mediaItems = response.items
            hasMoreItems = mediaItems.count < response.totalRecordCount
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadMoreItemsIfNeeded(currentItem: MediaItem) async {
        guard hasMoreItems,
              !isLoadingMore,
              let lastItem = mediaItems.last,
              currentItem.id == lastItem.id
        else {
            return
        }

        await loadMoreItems()
    }

    func loadMoreItems() async {
        guard let service = jellyfinService,
              hasMoreItems,
              !isLoadingMore
        else {
            return
        }
        guard !Task.isCancelled else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let response = try await service.getItems(
                parentID: selectedLibrary?.id,
                includeItemTypes: selectedMediaType.jellyfinTypes,
                limit: pageSize,
                startIndex: currentPage * pageSize
            )

            guard !Task.isCancelled else {
                currentPage -= 1
                isLoadingMore = false
                return
            }

            mediaItems.append(contentsOf: response.items)
            hasMoreItems = mediaItems.count < response.totalRecordCount
        } catch {
            currentPage -= 1
            if !Task.isCancelled {
                print("Failed to load more items: \(error)")
            }
        }

        isLoadingMore = false
    }

    func filterChanged() async {
        currentPage = 0
        hasMoreItems = true
        mediaItems = []
        await loadMediaItems()
    }

    func refresh() async {
        // Cancel any existing tasks
        loadTask?.cancel()
        refreshTask?.cancel()

        refreshTask = Task {
            guard !Task.isCancelled else { return }

            currentPage = 0
            hasMoreItems = true

            // Reset hasLoaded flags so skeleton states show during refresh
            hasLoadedLatestItems = false
            hasLoadedContinueWatching = false

            await loadInitialData()

            guard !Task.isCancelled else { return }

            if selectedLibrary != nil {
                await loadMediaItems()
            }
        }

        await refreshTask?.value
    }

    // MARK: - Image URLs

    enum ImageType: String {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
    }

    func imageURL(for item: MediaItem, type: ImageType = .primary) -> URL? {
        guard let serverURL else { return nil }
        return serverURL.appendingPathComponent("Items/\(item.id)/Images/\(type.rawValue)")
    }

    func imageURL(for library: Library) -> URL? {
        guard let serverURL else { return nil }
        return serverURL.appendingPathComponent("Items/\(library.id)/Images/Primary")
    }

    // MARK: - Task Management

    func cancelAllTasks() {
        loadTask?.cancel()
        refreshTask?.cancel()
        loadTask = nil
        refreshTask = nil
    }
}
