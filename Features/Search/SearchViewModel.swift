import Foundation
import JellyseerrClient
import SeerCore
import SwiftUI

/// View model for the search feature
@MainActor
public final class SearchViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    @Published var hasSearched: Bool = false

    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var isLoadingMore: Bool = false

    // MARK: - Private Properties

    private var jellyseerrService: JellyseerrService?
    private let appState: AppState
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(appState: AppState) {
        self.appState = appState
        setupService()
    }

    private func setupService() {
        guard let serverURL = appState.jellyseerrServerURL,
              let apiKey = appState.jellyseerrAPIKey
        else {
            return
        }

        jellyseerrService = JellyseerrService(serverURL: serverURL, apiKey: apiKey)
    }

    // MARK: - Public Methods

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }

        guard jellyseerrService != nil else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        // Cancel any existing search
        searchTask?.cancel()

        isSearching = true
        errorMessage = nil
        hasSearched = true
        currentPage = 1

        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300)) // Debounce

                guard !Task.isCancelled else { return }

                let response = try await jellyseerrService!.search(query: query, page: 1)

                guard !Task.isCancelled else { return }

                searchResults = response.results.filter { $0.mediaType != .person }
                totalPages = response.totalPages
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    searchResults = []
                }
            }

            isSearching = false
        }
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
            print("Failed to load more results: \(error)")
        }

        isLoadingMore = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        hasSearched = false
        errorMessage = nil
    }

    func serverChanged() {
        setupService()
        clearSearch()
    }

    // MARK: - Request Media

    func requestMedia(_ result: SearchResult) async throws {
        guard let service = jellyseerrService else {
            throw JellyseerrService.JellyseerrError.notAuthenticated
        }

        _ = try await service.createRequest(
            mediaType: result.mediaType,
            mediaId: result.id
        )
    }

    // MARK: - Helpers

    var isJellyseerrConfigured: Bool {
        appState.jellyseerrServerURL != nil && appState.jellyseerrAPIKey != nil
    }
}
