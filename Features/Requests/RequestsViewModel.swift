import Foundation
import JellyseerrClient
import SeerCore
import SwiftUI

/// View model for managing and viewing requests
@MainActor
public final class RequestsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var requests: [MediaRequest] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var selectedFilter: RequestFilter = .all
    @Published var selectedSort: RequestSort = .added

    enum RequestFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case available = "Available"
        case processing = "Processing"

        var apiFilter: JellyseerrService.RequestFilter {
            switch self {
            case .all: .all
            case .pending: .pending
            case .approved: .approved
            case .available: .available
            case .processing: .processing
            }
        }
    }

    enum RequestSort: String, CaseIterable {
        case added = "Recently Added"
        case modified = "Recently Modified"

        var apiSort: JellyseerrService.RequestSort {
            switch self {
            case .added: .added
            case .modified: .modified
            }
        }
    }

    // MARK: - Private Properties

    private var jellyseerrService: JellyseerrService?
    private let appState: AppState
    private var currentSkip: Int = 0
    private let pageSize: Int = 20
    private var hasMoreItems: Bool = true
    private var totalItems: Int = 0

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

    func loadRequests() async {
        guard jellyseerrService != nil else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        isLoading = true
        errorMessage = nil
        currentSkip = 0
        hasMoreItems = true

        do {
            let response = try await jellyseerrService!.getRequests(
                take: pageSize,
                skip: 0,
                filter: selectedFilter.apiFilter,
                sort: selectedSort.apiSort
            )

            requests = response.results
            totalItems = response.pageInfo.results
            hasMoreItems = requests.count < totalItems
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreRequestsIfNeeded(currentRequest: MediaRequest) async {
        guard hasMoreItems,
              !isLoadingMore,
              let lastRequest = requests.last,
              currentRequest.id == lastRequest.id
        else {
            return
        }

        await loadMoreRequests()
    }

    func loadMoreRequests() async {
        guard let service = jellyseerrService,
              hasMoreItems,
              !isLoadingMore
        else {
            return
        }

        isLoadingMore = true
        currentSkip += pageSize

        do {
            let response = try await service.getRequests(
                take: pageSize,
                skip: currentSkip,
                filter: selectedFilter.apiFilter,
                sort: selectedSort.apiSort
            )

            requests.append(contentsOf: response.results)
            hasMoreItems = requests.count < response.pageInfo.results
        } catch {
            currentSkip -= pageSize
            print("Failed to load more requests: \(error)")
        }

        isLoadingMore = false
    }

    func filterChanged() async {
        currentSkip = 0
        hasMoreItems = true
        await loadRequests()
    }

    func refresh() async {
        await loadRequests()
    }

    // MARK: - Helpers

    /// Cancel a request by ID
    func cancelRequest(_ request: MediaRequest) async throws {
        guard let service = jellyseerrService else { return }
        try await service.cancelRequest(id: request.id)
        // Refresh to update the list
        await refresh()
    }

    var isJellyseerrConfigured: Bool {
        appState.jellyseerrServerURL != nil && appState.jellyseerrAPIKey != nil
    }

    func posterURL(for _: MediaRequest) -> URL? {
        // We don't have the poster path from the request directly
        // This would need to be fetched from TMDB if needed
        nil
    }
}
