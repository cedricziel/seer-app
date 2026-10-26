import Foundation
import JellyseerrClient
import os
import SeerCore

/// ViewModel for the Discover tab
@MainActor
public final class DiscoverViewModel: ObservableObject, RequestOptionsProvider {
    private static let logger = Logger(subsystem: "com.seer.app", category: "DiscoverViewModel")

    // MARK: - Published Properties

    // Content
    @Published var trending: [SearchResult] = []
    @Published var upcomingMovies: [SearchResult] = []
    @Published var upcomingTV: [SearchResult] = []
    @Published var movieGenres: [DiscoverGenre] = []
    @Published var tvGenres: [DiscoverGenre] = []

    // Loading states
    @Published var isLoading: Bool = false
    @Published var isLoadingTrending: Bool = false
    @Published var isLoadingUpcomingMovies: Bool = false
    @Published var isLoadingUpcomingTV: Bool = false
    @Published var isLoadingGenres: Bool = false
    @Published var errorMessage: String?

    // TV Details for season selection
    @Published var tvDetails: TVDetails?
    @Published var isLoadingTVDetails: Bool = false

    // Pagination state
    @Published var trendingPage: Int = 1
    @Published var trendingTotalPages: Int = 1
    @Published var upcomingMoviesPage: Int = 1
    @Published var upcomingMoviesTotalPages: Int = 1
    @Published var upcomingTVPage: Int = 1
    @Published var upcomingTVTotalPages: Int = 1

    // MARK: - Private Properties

    private enum Section: String, CaseIterable {
        case trending = "Trending"
        case movies = "Upcoming Movies"
        case television = "Upcoming TV Shows"
        case movieGenres = "Movie Genres"
        case tvGenres = "TV Genres"
    }

    private var failedSections: Set<Section> = []
    private var service: JellyseerrService?
    private var serviceConfigurationID: AppState.ServiceConfigurationID?
    private var jellyseerrService: JellyseerrService? {
        if serviceConfigurationID != appState.serviceConfigurationID {
            setupService()
        }
        return service
    }

    private let appState: AppState
    private let session: URLSession?

    // MARK: - Initialization

    public init(appState: AppState, session: URLSession? = nil) {
        self.appState = appState
        self.session = session
        setupService()
    }

    private func setupService() {
        service = nil
        serviceConfigurationID = appState.serviceConfigurationID
        trending = []
        upcomingMovies = []
        upcomingTV = []
        movieGenres = []
        tvGenres = []
        tvDetails = nil
        errorMessage = nil
        failedSections = []
        isLoading = false
        isLoadingTrending = false
        isLoadingUpcomingMovies = false
        isLoadingUpcomingTV = false
        isLoadingGenres = false
        isLoadingTVDetails = false
        guard let serverURL = appState.jellyseerrServerURL,
              let apiKey = appState.jellyseerrAPIKey
        else {
            return
        }

        service = JellyseerrService(serverURL: serverURL, apiKey: apiKey, session: session)

        // Load permissions if not already set
        if appState.jellyseerrUserPermissions == 0 {
            let configurationID = appState.serviceConfigurationID
            let permissionService = service
            Task {
                await loadUserPermissions(service: permissionService, configurationID: configurationID)
            }
        }
    }

    /// Load user permissions from Jellyseerr
    func loadUserPermissions(
        service: JellyseerrService?, configurationID: AppState.ServiceConfigurationID
    ) async {
        guard let service else { return }

        do {
            let userInfo = try await service.verifyAuth()
            guard configurationID == appState.serviceConfigurationID else { return }
            appState.setJellyseerrPermissions(userInfo.permissions)
        } catch {
            Self.logger.debug("Failed to load Jellyseerr permissions: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    /// Load all initial data for the discover view
    func loadInitialData() async {
        guard jellyseerrService != nil else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        guard !isLoading else { return }
        let configurationID = appState.serviceConfigurationID
        isLoading = true

        // Load all sections in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTrending() }
            group.addTask { await self.loadUpcomingMovies() }
            group.addTask { await self.loadUpcomingTV() }
            group.addTask { await self.loadGenres() }
        }

        guard configurationID == appState.serviceConfigurationID else { return }
        isLoading = false
    }

    /// Load trending content
    func loadTrending() async {
        guard let service = jellyseerrService else { return }
        let configurationID = appState.serviceConfigurationID

        isLoadingTrending = true

        do {
            let response = try await service.getTrending(page: 1)
            guard configurationID == appState.serviceConfigurationID else { return }
            trending = response.results
            trendingPage = response.page
            trendingTotalPages = response.totalPages
            setFailure(false, for: .trending)
        } catch {
            guard configurationID == appState.serviceConfigurationID else { return }
            Self.logger.debug("Failed to load trending: \(error.localizedDescription)")
            setFailure(true, for: .trending)
        }

        isLoadingTrending = false
    }

    /// Load upcoming movies
    func loadUpcomingMovies() async {
        guard let service = jellyseerrService else { return }
        let configurationID = appState.serviceConfigurationID

        isLoadingUpcomingMovies = true

        do {
            let response = try await service.getUpcomingMovies(page: 1)
            guard configurationID == appState.serviceConfigurationID else { return }
            upcomingMovies = response.results
            upcomingMoviesPage = response.page
            upcomingMoviesTotalPages = response.totalPages
            setFailure(false, for: .movies)
        } catch {
            guard configurationID == appState.serviceConfigurationID else { return }
            Self.logger.debug("Failed to load upcoming movies: \(error.localizedDescription)")
            setFailure(true, for: .movies)
        }

        isLoadingUpcomingMovies = false
    }

    /// Load upcoming TV shows
    func loadUpcomingTV() async {
        guard let service = jellyseerrService else { return }
        let configurationID = appState.serviceConfigurationID

        isLoadingUpcomingTV = true

        do {
            let response = try await service.getUpcomingTV(page: 1)
            guard configurationID == appState.serviceConfigurationID else { return }
            upcomingTV = response.results
            upcomingTVPage = response.page
            upcomingTVTotalPages = response.totalPages
            setFailure(false, for: .television)
        } catch {
            guard configurationID == appState.serviceConfigurationID else { return }
            Self.logger.debug("Failed to load upcoming TV: \(error.localizedDescription)")
            setFailure(true, for: .television)
        }

        isLoadingUpcomingTV = false
    }

    /// Load movie and TV genres
    func loadGenres() async {
        guard let service = jellyseerrService else { return }
        let configurationID = appState.serviceConfigurationID

        isLoadingGenres = true

        async let movies: () = loadGenres(service: service, configurationID: configurationID, isMovie: true)
        async let television: () = loadGenres(service: service, configurationID: configurationID, isMovie: false)
        _ = await (movies, television)

        guard configurationID == appState.serviceConfigurationID else { return }
        isLoadingGenres = false
    }

    private func loadGenres(
        service: JellyseerrService, configurationID: AppState.ServiceConfigurationID, isMovie: Bool
    ) async {
        let section: Section = isMovie ? .movieGenres : .tvGenres
        do {
            let genres: [DiscoverGenre] = if isMovie {
                try await service.getMovieGenres()
            } else {
                try await service.getTVGenres()
            }
            guard configurationID == appState.serviceConfigurationID else { return }
            if isMovie {
                movieGenres = genres
            } else {
                tvGenres = genres
            }
            setFailure(false, for: section)
        } catch {
            guard configurationID == appState.serviceConfigurationID else { return }
            Self.logger.debug("Failed to load genres: \(error.localizedDescription)")
            setFailure(true, for: section)
        }
    }

    private func setFailure(_ failed: Bool, for section: Section) {
        if failed {
            failedSections.insert(section)
        } else {
            failedSections.remove(section)
        }
        let names = Section.allCases.filter { failedSections.contains($0) }.map(\.rawValue)
        errorMessage = names.isEmpty
            ? nil
            : "Couldn't load \(names.joined(separator: ", ")). Check your connection and try again."
    }

    /// Refresh all content
    func refresh() async {
        await loadInitialData()
    }

    /// Handle server change
    func serverChanged() {
        setupService()
        trending = []
        upcomingMovies = []
        upcomingTV = []
        movieGenres = []
        tvGenres = []
        tvDetails = nil
        errorMessage = nil

        Task {
            await loadInitialData()
        }
    }

    // MARK: - TV Details

    /// Load TV details for season selection
    func loadTVDetails(tmdbId: Int) async {
        guard let service = jellyseerrService else { return }
        let configurationID = appState.serviceConfigurationID

        isLoadingTVDetails = true
        tvDetails = nil

        do {
            let details = try await service.getTVDetails(tmdbId: tmdbId)
            guard configurationID == appState.serviceConfigurationID else { return }
            tvDetails = details
        } catch {
            guard configurationID == appState.serviceConfigurationID else { return }
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

    /// Check if any content is available
    var hasContent: Bool {
        !trending.isEmpty || !upcomingMovies.isEmpty || !upcomingTV.isEmpty ||
            !movieGenres.isEmpty || !tvGenres.isEmpty
    }

    /// Check if all content sections are loading
    var isLoadingAll: Bool {
        isLoadingTrending && isLoadingUpcomingMovies && isLoadingUpcomingTV && isLoadingGenres
    }
}
