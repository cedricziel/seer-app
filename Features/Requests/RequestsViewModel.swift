import Foundation
import JellyseerrClient
import os
import SeerCore
import SwiftUI

/// View model for managing and viewing requests
@MainActor
public final class RequestsViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.seer.app", category: "RequestsViewModel")

    // MARK: - Published Properties

    @Published var requests: [MediaRequest] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var selectedFilter: RequestFilter = .all
    @Published var selectedSort: RequestSort = .added

    /// Cache of media titles by TMDB ID
    @Published var mediaTitles: [Int: String] = [:]
    /// Cache of poster paths by TMDB ID
    @Published var mediaPosterPaths: [Int: String] = [:]

    enum RequestFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case declined = "Declined"
        case available = "Available"
        case processing = "Processing"

        var apiFilter: JellyseerrService.RequestFilter {
            switch self {
            case .all: .all
            case .pending: .pending
            case .approved: .approved
            case .declined: .declined
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

    // MARK: - Configuration

    /// How often to silently refresh the request list while the user is on
    /// the Requests tab. 45s is short enough that approvals/availability
    /// transitions surface promptly without hammering the server.
    public static let defaultAutoRefreshInterval: TimeInterval = 45

    // MARK: - Private Properties

    private var jellyseerrService: JellyseerrService?
    private let appState: AppState
    private let autoRefreshScheduler: RefreshScheduler
    private var currentSkip: Int = 0
    private let pageSize: Int = 20
    private var hasMoreItems: Bool = true
    private var totalItems: Int = 0

    // MARK: - Initialization

    public init(
        appState: AppState,
        autoRefreshScheduler: RefreshScheduler = RefreshScheduler(
            interval: RequestsViewModel.defaultAutoRefreshInterval
        )
    ) {
        self.appState = appState
        self.autoRefreshScheduler = autoRefreshScheduler
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

            // Fetch media details (titles, posters) in background
            Task {
                await fetchMediaDetails()
            }
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
            Self.logger.debug("Failed to load more requests: \(error.localizedDescription)")
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

    // MARK: - Auto-refresh

    /// Starts polling for status changes while the view is visible. No-op
    /// when Jellyseerr isn't configured.
    func startAutoRefresh() {
        guard isJellyseerrConfigured else { return }
        autoRefreshScheduler.start { [weak self] in
            await self?.silentRefresh()
        }
    }

    /// Stops the polling loop. Call from `onDisappear` so we don't keep
    /// hitting the server on a tab the user has left.
    func stopAutoRefresh() {
        autoRefreshScheduler.stop()
    }

    /// Refreshes without flipping `isLoading` so we don't yank the list
    /// from under the user mid-scroll.
    func silentRefresh() async {
        guard let service = jellyseerrService else { return }
        do {
            let response = try await service.getRequests(
                take: pageSize,
                skip: 0,
                filter: selectedFilter.apiFilter,
                sort: selectedSort.apiSort
            )
            requests = response.results
            totalItems = response.pageInfo.results
            hasMoreItems = requests.count < totalItems
            currentSkip = 0
            errorMessage = nil
        } catch {
            // Background refresh failures shouldn't surface — the user will
            // see the next manual refresh attempt if it persists.
            Self.logger.debug("Auto-refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Request Actions

    /// Cancel a request by ID
    func cancelRequest(_ request: MediaRequest) async throws {
        guard let service = jellyseerrService else { return }
        try await service.cancelRequest(id: request.id)
        // Refresh to update the list
        await refresh()
    }

    /// Approve a pending request (admin only)
    func approveRequest(_ request: MediaRequest) async throws {
        guard let service = jellyseerrService else { return }
        _ = try await service.approveRequest(id: request.id)
        // Refresh to update the list
        await refresh()
    }

    /// Decline a pending request (admin only)
    func declineRequest(_ request: MediaRequest) async throws {
        guard let service = jellyseerrService else { return }
        _ = try await service.declineRequest(id: request.id)
        // Refresh to update the list
        await refresh()
    }

    // MARK: - Computed Properties

    var isJellyseerrConfigured: Bool {
        appState.jellyseerrServerURL != nil && appState.jellyseerrAPIKey != nil
    }

    /// Whether the current user can manage requests (approve/decline)
    var canManageRequests: Bool {
        appState.canManageRequests
    }

    func posterURL(for request: MediaRequest) -> URL? {
        guard let tmdbId = request.media.tmdbId,
              let posterPath = mediaPosterPaths[tmdbId]
        else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")
    }

    /// Get the display title for a request (from cache or fallback)
    func displayTitle(for request: MediaRequest) -> String {
        if let title = request.media.displayTitle, !title.isEmpty {
            return title
        }
        if let tmdbId = request.media.tmdbId, let cachedTitle = mediaTitles[tmdbId] {
            return cachedTitle
        }
        if let tmdbId = request.media.tmdbId {
            return "TMDB #\(tmdbId)"
        }
        return "Request #\(request.id)"
    }

    /// Fetch media details (title, poster) for all requests
    func fetchMediaDetails() async {
        guard let service = jellyseerrService else { return }

        for request in requests {
            guard let tmdbId = request.media.tmdbId else { continue }

            // Skip if already cached
            if mediaTitles[tmdbId] != nil { continue }

            do {
                if request.type == .movie {
                    let details = try await service.getMovieDetails(tmdbId: tmdbId)
                    mediaTitles[tmdbId] = details.title
                    if let posterPath = details.posterPath {
                        mediaPosterPaths[tmdbId] = posterPath
                    }
                } else {
                    let details = try await service.getTVDetails(tmdbId: tmdbId)
                    mediaTitles[tmdbId] = details.name
                    if let posterPath = details.posterPath {
                        mediaPosterPaths[tmdbId] = posterPath
                    }
                }
            } catch {
                // Silently fail for individual lookups
                Self.logger.debug("Failed to fetch details for TMDB ID \(tmdbId): \(error.localizedDescription)")
            }
        }
    }
}
