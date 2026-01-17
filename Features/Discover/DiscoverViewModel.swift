import Foundation
import JellyseerrClient
import SeerCore

/// ViewModel for the Discover tab
@MainActor
public final class DiscoverViewModel: ObservableObject, RequestOptionsProvider {
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

    private var jellyseerrService: JellyseerrService?
    private let appState: AppState

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
            print("Failed to load Jellyseerr permissions: \(error)")
        }
    }

    // MARK: - Public Methods

    /// Load all initial data for the discover view
    func loadInitialData() async {
        guard jellyseerrService != nil else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        isLoading = true
        errorMessage = nil

        // Load all sections in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTrending() }
            group.addTask { await self.loadUpcomingMovies() }
            group.addTask { await self.loadUpcomingTV() }
            group.addTask { await self.loadGenres() }
        }

        isLoading = false
    }

    /// Load trending content
    func loadTrending() async {
        guard let service = jellyseerrService else { return }

        isLoadingTrending = true

        do {
            let response = try await service.getTrending(page: 1)
            trending = response.results
            trendingPage = response.page
            trendingTotalPages = response.totalPages
        } catch {
            print("Failed to load trending: \(error)")
        }

        isLoadingTrending = false
    }

    /// Load upcoming movies
    func loadUpcomingMovies() async {
        guard let service = jellyseerrService else { return }

        isLoadingUpcomingMovies = true

        do {
            let response = try await service.getUpcomingMovies(page: 1)
            upcomingMovies = response.results
            upcomingMoviesPage = response.page
            upcomingMoviesTotalPages = response.totalPages
        } catch {
            print("Failed to load upcoming movies: \(error)")
        }

        isLoadingUpcomingMovies = false
    }

    /// Load upcoming TV shows
    func loadUpcomingTV() async {
        guard let service = jellyseerrService else { return }

        isLoadingUpcomingTV = true

        do {
            let response = try await service.getUpcomingTV(page: 1)
            upcomingTV = response.results
            upcomingTVPage = response.page
            upcomingTVTotalPages = response.totalPages
        } catch {
            print("Failed to load upcoming TV: \(error)")
        }

        isLoadingUpcomingTV = false
    }

    /// Load movie and TV genres
    func loadGenres() async {
        guard let service = jellyseerrService else { return }

        isLoadingGenres = true

        do {
            async let movieGenresTask = service.getMovieGenres()
            async let tvGenresTask = service.getTVGenres()

            movieGenres = try await movieGenresTask
            tvGenres = try await tvGenresTask
        } catch {
            print("Failed to load genres: \(error)")
        }

        isLoadingGenres = false
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

        isLoadingTVDetails = true
        tvDetails = nil

        do {
            tvDetails = try await service.getTVDetails(tmdbId: tmdbId)
        } catch {
            print("Failed to load TV details: \(error)")
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
