import Combine
import Foundation
import JellyseerrClient
import os
import SeerCore
import SwiftData

protocol RequestService: AnyObject, Sendable {
    func getRequests(
        take: Int,
        skip: Int,
        filter: JellyseerrService.RequestFilter,
        sort: JellyseerrService.RequestSort
    ) async throws -> RequestsResponse
    func cancelRequest(id: Int) async throws
    func approveRequest(id: Int) async throws -> MediaRequest
    func declineRequest(id: Int) async throws -> MediaRequest
    func getMovieDetails(tmdbId: Int) async throws -> MovieDetails
    func getTVDetails(tmdbId: Int) async throws -> TVDetails
}

extension JellyseerrService: RequestService {}

/// View model for managing and viewing requests
@MainActor
public final class RequestsViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.seer.app", category: "RequestsViewModel")

    // MARK: - Published Properties

    @Published var requests: [MediaRequest] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var selectedFilter: RequestFilter = .all {
        didSet {
            if oldValue != selectedFilter {
                invalidateLoads()
            }
        }
    }

    @Published var selectedSort: RequestSort = .added {
        didSet {
            if oldValue != selectedSort {
                invalidateLoads()
            }
        }
    }

    @Published private(set) var requestIdentity = UUID()

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

    private var jellyseerrService: (any RequestService)?
    private var serverIdentity: () -> UUID?
    private var serviceServerID: UUID?
    private let serviceFactory: () -> (any RequestService)?
    private let appState: AppState
    private let autoRefreshScheduler: RefreshScheduler
    private struct Scope: Equatable {
        let serverID: UUID
        let filter: RequestFilter
        let sort: RequestSort
    }

    private var generation = UUID()
    private var visibleScope: Scope?
    private var currentScope: Scope? {
        guard let serverID = serverIdentity() else { return nil }
        return Scope(serverID: serverID, filter: selectedFilter, sort: selectedSort)
    }

    private func invalidateLoads() {
        generation = UUID()
        isLoading = false
        isLoadingMore = false
    }

    private func owns(_ operation: UUID, scope: Scope) -> Bool {
        generation == operation && currentScope == scope
    }

    private var currentSkip: Int = 0
    private let pageSize: Int = 20
    private var hasMoreItems: Bool = true
    private var totalItems: Int = 0

    // MARK: - Initialization

    public init(
        appState: AppState,
        autoRefreshScheduler: RefreshScheduler? = nil
    ) {
        self.appState = appState
        serverIdentity = { appState.activeServerID }
        serviceFactory = {
            guard let url = appState.jellyseerrServerURL, let key = appState.jellyseerrAPIKey else { return nil }
            return JellyseerrService(serverURL: url, apiKey: key)
        }
        self.autoRefreshScheduler = autoRefreshScheduler
            ?? RefreshScheduler(interval: Self.defaultAutoRefreshInterval)
        setupService()
    }

    init(appState: AppState, service: any RequestService, serverIdentity: @escaping () -> UUID?) {
        self.appState = appState
        self.serverIdentity = serverIdentity
        autoRefreshScheduler = RefreshScheduler(interval: Self.defaultAutoRefreshInterval)
        serviceFactory = { service }
        setupService()
    }

    private func setupService() {
        serviceServerID = serverIdentity()
        jellyseerrService = serviceFactory()
    }

    /// Tear down auto-refresh, rebuild the Jellyseerr client against the
    /// new active server, then refresh and resume polling.
    func handleActiveServerChange() async {
        stopAutoRefresh()
        invalidateLoads()
        requestIdentity = UUID()
        visibleScope = nil
        setupService()
        currentSkip = 0
        hasMoreItems = true
        requests = []
        mediaTitles = [:]
        mediaPosterPaths = [:]
        await loadRequests()
        startAutoRefresh()
    }

    // MARK: - Public Methods

    func loadRequests() async {
        if serviceServerID != serverIdentity() {
            setupService()
            requests = []
            visibleScope = nil
            requestIdentity = UUID()
            mediaTitles = [:]
            mediaPosterPaths = [:]
        }
        invalidateLoads()
        guard let service = jellyseerrService, let scope = currentScope else {
            errorMessage = "Jellyseerr not configured"
            return
        }
        let operation = generation
        isLoading = true
        errorMessage = nil
        defer {
            if owns(operation, scope: scope) {
                isLoading = false
            }
        }
        do {
            let response = try await service.getRequests(
                take: pageSize, skip: 0, filter: scope.filter.apiFilter, sort: scope.sort.apiSort
            )
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            publish(response, scope: scope)
            Task { await fetchMediaDetails() }
        } catch {
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func publish(_ response: RequestsResponse, scope: Scope) {
        requests = response.results
        visibleScope = scope
        requestIdentity = UUID()
        totalItems = response.pageInfo.results
        hasMoreItems = requests.count < totalItems
        currentSkip = 0
        errorMessage = nil
        cacheLiveRequestsToSwiftData(response, filter: scope.filter, serverID: scope.serverID)
    }

    private func cacheLiveRequestsToSwiftData(
        _ response: RequestsResponse, filter: RequestFilter, serverID: UUID
    ) {
        guard let context = appState.sharedModelContext else { return }
        do {
            try Self.cacheRequests(response, filter: filter, serverID: serverID, context: context)
        } catch {
            Self.logger.error("Failed to cache requests for AppEntity query: \(String(describing: error))")
        }
    }

    static func cacheRequests(
        _ response: RequestsResponse, filter: RequestFilter, serverID: UUID, context: ModelContext
    ) throws {
        let liveIDs = Set(response.results.map { request -> String in
            "\(serverID.uuidString):\(request.id)"
        })

        let existingDescriptor = FetchDescriptor<CachedRequest>(
            predicate: #Predicate { $0.serverConfigurationID == serverID }
        )
        let existing = try context.fetch(existingDescriptor)
        // The CloudKit-backed store cannot enforce uniqueness, so keep
        // the first row per id and drop duplicates rather than trapping.
        var existingByID: [String: CachedRequest] = [:]
        for row in existing {
            if existingByID[row.id] == nil {
                existingByID[row.id] = row
            } else {
                context.delete(row)
            }
        }

        for live in response.results {
            let title = live.media.displayTitle ?? "Untitled"
            if let row = existingByID[
                "\(serverID.uuidString):\(live.id)"
            ] {
                row.title = title
                row.mediaType = live.type.rawValue
                row.statusRawValue = live.status.rawValue
                row.mediaTmdbId = live.media.tmdbId
                row.availabilityRawValue = live.media.status
                row.lastSyncedAt = Date()
            } else {
                context.insert(
                    CachedRequest(
                        serverConfigurationID: serverID,
                        requestID: live.id,
                        title: title,
                        mediaType: live.type.rawValue,
                        statusRawValue: live.status.rawValue,
                        requestedAt: Date(),
                        mediaTmdbId: live.media.tmdbId,
                        availabilityRawValue: live.media.status
                    )
                )
            }
        }

        // A filtered or partial page cannot establish that an absent request was deleted.
        if filter == .all, response.pageInfo.page == 1, response.results.count == response.pageInfo.results {
            for row in existing where !liveIDs.contains(row.id) {
                context.delete(row)
            }
        }

        try context.save()
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
        guard let service = jellyseerrService, let scope = currentScope,
              visibleScope == scope, serviceServerID == scope.serverID, hasMoreItems, !isLoading,
              !isLoadingMore else { return }
        generation = UUID()
        let operation = generation
        let skip = currentSkip + pageSize
        isLoadingMore = true
        defer {
            if owns(operation, scope: scope) {
                isLoadingMore = false
            }
        }
        do {
            let response = try await service.getRequests(
                take: pageSize, skip: skip, filter: scope.filter.apiFilter, sort: scope.sort.apiSort
            )
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            currentSkip = skip
            requests.append(contentsOf: response.results)
            hasMoreItems = requests.count < response.pageInfo.results
            cacheLiveRequestsToSwiftData(response, filter: scope.filter, serverID: scope.serverID)
        } catch {
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            Self.logger.debug("Failed to load more requests: \(error.localizedDescription)")
        }
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
        guard !isLoading, !isLoadingMore,
              let service = jellyseerrService, let scope = currentScope,
              serviceServerID == scope.serverID else { return }
        generation = UUID()
        let operation = generation
        do {
            let response = try await service.getRequests(
                take: pageSize, skip: 0, filter: scope.filter.apiFilter, sort: scope.sort.apiSort
            )
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            publish(response, scope: scope)
        } catch {
            guard owns(operation, scope: scope), !Task.isCancelled else { return }
            Self.logger.debug("Auto-refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Request Actions

    func cancelRequest(_ request: MediaRequest, identity: UUID) async throws {
        try await performAction(.cancel, request: request, identity: identity)
    }

    func approveRequest(_ request: MediaRequest, identity: UUID) async throws {
        try await performAction(.approve, request: request, identity: identity)
    }

    func declineRequest(_ request: MediaRequest, identity: UUID) async throws {
        try await performAction(.decline, request: request, identity: identity)
    }

    private enum RequestAction { case cancel, approve, decline }

    private func performAction(_ action: RequestAction, request: MediaRequest, identity: UUID) async throws {
        guard requestIdentity == identity, let scope = currentScope,
              visibleScope == scope, serviceServerID == scope.serverID, requests.contains(request),
              let service = jellyseerrService else { return }
        do {
            switch action {
            case .cancel: try await service.cancelRequest(id: request.id)
            case .approve: _ = try await service.approveRequest(id: request.id)
            case .decline: _ = try await service.declineRequest(id: request.id)
            }
        } catch {
            guard currentScope == scope, requestIdentity == identity else { return }
            throw error
        }
        guard currentScope == scope, requestIdentity == identity else { return }
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
        guard let service = jellyseerrService, let scope = currentScope, visibleScope == scope else { return }
        let identity = requestIdentity
        let snapshot = requests

        for request in snapshot {
            guard currentScope == scope, requestIdentity == identity else { return }
            guard let tmdbId = request.media.tmdbId else { continue }

            // Skip if already cached
            if mediaTitles[tmdbId] != nil {
                continue
            }

            do {
                let (title, posterPath) = try await mediaDetails(for: request, tmdbId: tmdbId, service: service)
                guard currentScope == scope, requestIdentity == identity else { return }
                mediaTitles[tmdbId] = title
                if let posterPath {
                    mediaPosterPaths[tmdbId] = posterPath
                }
            } catch {
                // Silently fail for individual lookups
                Self.logger.debug("Failed to fetch details for TMDB ID \(tmdbId): \(error.localizedDescription)")
            }
        }
    }

    private func mediaDetails(
        for request: MediaRequest, tmdbId: Int, service: any RequestService
    ) async throws -> (String, String?) {
        if request.type == .movie {
            let details = try await service.getMovieDetails(tmdbId: tmdbId)
            return (details.title, details.posterPath)
        }
        let details = try await service.getTVDetails(tmdbId: tmdbId)
        return (details.name, details.posterPath)
    }
}
