import Foundation
import JellyseerrClient
import os
import SeerCore
import SwiftUI

/// View model for the search feature
@MainActor
public final class SearchViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.seer.app", category: "SearchViewModel")

    // MARK: - Published Properties

    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    /// True while we're waiting out the debounce window before kicking off a
    /// network request. Surfaces a "Searching…" hint so users know typing
    /// hasn't been swallowed.
    @Published var isDebouncing: Bool = false
    @Published var errorMessage: String?
    @Published var hasSearched: Bool = false
    @Published var recentQueries: [String] = []

    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var isLoadingMore: Bool = false

    // TV Details for season selection
    @Published var tvDetails: TVDetails?
    @Published var isLoadingTVDetails: Bool = false

    // MARK: - Configuration

    /// Debounce window before issuing a search request. Exposed so tests can
    /// drive a short interval.
    static let defaultDebounceMilliseconds: Int = 300

    // MARK: - Private Properties

    private var jellyseerrService: JellyseerrService?
    private let appState: AppState
    private let historyStore: SearchHistoryStore
    private let debounceMilliseconds: Int
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        appState: AppState,
        historyStore: SearchHistoryStore = SearchHistoryStore(),
        debounceMilliseconds: Int = SearchViewModel.defaultDebounceMilliseconds
    ) {
        self.appState = appState
        self.historyStore = historyStore
        self.debounceMilliseconds = debounceMilliseconds
        setupService()
        recentQueries = historyStore.recentQueries(scope: historyScope)
    }

    private func setupService() {
        guard let serverURL = appState.jellyseerrServerURL,
              let apiKey = appState.jellyseerrAPIKey
        else {
            return
        }

        jellyseerrService = JellyseerrService(serverURL: serverURL, apiKey: apiKey)

        // Load permissions if not already set
        if appState.jellyseerrUserPermissions == 0 {
            Task {
                await loadUserPermissions()
            }
        }
    }

    /// Load user permissions from Jellyseerr
    private func loadUserPermissions() async {
        guard let service = jellyseerrService else { return }

        do {
            let userInfo = try await service.verifyAuth()
            appState.setJellyseerrPermissions(userInfo.permissions)
        } catch {
            Self.logger.debug("Failed to load Jellyseerr permissions: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchTask?.cancel()
            searchResults = []
            hasSearched = false
            isSearching = false
            isDebouncing = false
            return
        }

        guard jellyseerrService != nil else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        // Cancel any existing search
        searchTask?.cancel()

        isDebouncing = true
        errorMessage = nil
        hasSearched = true
        currentPage = 1

        let debounce = debounceMilliseconds
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(debounce))

                guard !Task.isCancelled else { return }

                isDebouncing = false
                isSearching = true

                let response = try await jellyseerrService!.search(query: query, page: 1)

                guard !Task.isCancelled else { return }

                searchResults = response.results.filter { $0.mediaType != .person }
                totalPages = response.totalPages
                recordSearchHistory(query)
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    searchResults = []
                }
            }

            isDebouncing = false
            isSearching = false
        }
    }

    /// Re-runs a query the user picked from the recents list.
    func runRecentQuery(_ query: String) async {
        searchQuery = query
        await search()
    }

    /// Removes a single query from the recents list.
    func removeRecentQuery(_ query: String) {
        recentQueries = historyStore.remove(query, scope: historyScope)
    }

    /// Clears all recent queries.
    func clearRecentQueries() {
        historyStore.clear(scope: historyScope)
        recentQueries = []
    }

    func loadMoreResults() async {
        guard let service = jellyseerrService,
              currentPage < totalPages,
              !isLoadingMore,
              !searchQuery.isEmpty
        else {
            return
        }

        isLoadingMore = true
        currentPage += 1

        do {
            let response = try await service.search(query: searchQuery, page: currentPage)
            let newResults = response.results.filter { $0.mediaType != .person }
            searchResults.append(contentsOf: newResults)
        } catch {
            currentPage -= 1
            Self.logger.debug("Failed to load more results: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        hasSearched = false
        errorMessage = nil
        tvDetails = nil
        isDebouncing = false
        isSearching = false
    }

    func serverChanged() {
        setupService()
        clearSearch()
        recentQueries = historyStore.recentQueries(scope: historyScope)
    }

    // MARK: - History

    /// Scopes search history per server so multi-server users don't see
    /// other households' queries.
    private var historyScope: String {
        appState.activeServerID?.uuidString ?? "default"
    }

    private func recordSearchHistory(_ query: String) {
        recentQueries = historyStore.record(query, scope: historyScope)
    }

    // MARK: - TV Details

    /// Load TV details for season selection
    func loadTVDetails(tmdbId: Int) async {
        guard let service = jellyseerrService else { return }

        isLoadingTVDetails = true
        tvDetails = nil

        do {
            tvDetails = try await service.getTVDetails(tmdbId: tmdbId)
        } catch {
            Self.logger.debug("Failed to load TV details: \(error.localizedDescription)")
        }

        isLoadingTVDetails = false
    }

    /// Clear loaded TV details
    func clearTVDetails() {
        tvDetails = nil
    }

    // MARK: - Request Media

    /// Simple request for movies
    func requestMedia(_ result: SearchResult) async throws {
        guard let service = jellyseerrService else {
            throw JellyseerrService.JellyseerrError.notAuthenticated
        }

        _ = try await service.createRequest(
            mediaType: result.mediaType,
            mediaId: result.id
        )
    }

    /// Request media with options (seasons for TV, 4K)
    func requestMediaWithOptions(
        _ result: SearchResult,
        seasons: [Int]? = nil,
        is4k: Bool = false
    ) async throws {
        guard let service = jellyseerrService else {
            throw JellyseerrService.JellyseerrError.notAuthenticated
        }

        _ = try await service.createRequest(
            mediaType: result.mediaType,
            mediaId: result.id,
            seasons: seasons,
            is4k: is4k
        )
    }

    // MARK: - Computed Properties

    var isJellyseerrConfigured: Bool {
        appState.jellyseerrServerURL != nil && appState.jellyseerrAPIKey != nil
    }

    /// Whether the user can request 4K content
    var canRequest4K: Bool {
        appState.canRequest4K
    }

    /// Whether TV show has seasons available for selection
    var hasSeasons: Bool {
        guard let details = tvDetails,
              let seasons = details.seasons
        else {
            return false
        }
        return !seasons.isEmpty
    }

    /// Get available seasons from TV details
    var availableSeasons: [TVDetails.Season] {
        tvDetails?.seasons?.filter { $0.seasonNumber > 0 } ?? []
    }
}
