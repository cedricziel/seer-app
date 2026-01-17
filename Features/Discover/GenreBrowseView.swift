import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// View for browsing media by genre with pagination
struct GenreBrowseView: View {
    let genre: DiscoverGenre
    let mediaType: MediaTypeBadge.MediaType
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: GenreBrowseViewModel

    init(genre: DiscoverGenre, mediaType: MediaTypeBadge.MediaType, appState: AppState) {
        self.genre = genre
        self.mediaType = mediaType
        self.appState = appState
        _viewModel = StateObject(wrappedValue: GenreBrowseViewModel(
            genre: genre,
            mediaType: mediaType,
            appState: appState
        ))
    }

    var body: some View {
        GenreBrowseContentView(viewModel: viewModel, appState: appState)
            .navigationTitle(genre.name)
            .navigationBarTitleDisplayMode(.large)
    }
}

/// Internal content view
private struct GenreBrowseContentView: View {
    @ObservedObject var viewModel: GenreBrowseViewModel
    @ObservedObject var appState: AppState

    @State private var selectedResult: SearchResult?
    @State private var isRequestingMedia: Bool = false
    @State private var requestError: String?
    @State private var showRequestSuccess: Bool = false

    // Request options
    @State private var showRequestOptions: Bool = false
    @State private var requestOptionsResult: SearchResult?

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.results.isEmpty {
                LoadingView(message: "Loading...")
            } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.loadInitial() }
                }
            } else if viewModel.results.isEmpty {
                EmptyContentView(
                    title: "No Results",
                    systemImage: "film",
                    description: "No content found for this genre"
                )
            } else {
                resultsGrid
            }
        }
        .task {
            if viewModel.results.isEmpty {
                await viewModel.loadInitial()
            }
        }
        .alert("Request Submitted", isPresented: $showRequestSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your request has been submitted successfully.")
        }
        .alert("Request Failed", isPresented: .init(
            get: { requestError != nil },
            set: { if !$0 { requestError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(requestError ?? "An error occurred")
        }
        .sheet(item: $selectedResult) { result in
            SearchResultDetailSheet(
                result: result,
                canRequest4K: viewModel.canRequest4K,
                onRequest: {
                    handleRequestAction(result)
                },
                isRequesting: isRequestingMedia
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRequestOptions) {
            if let result = requestOptionsResult {
                SharedRequestOptionsSheet(
                    result: result,
                    provider: viewModel,
                    canRequest4K: viewModel.canRequest4K,
                    onSubmit: { seasons, is4k in
                        Task {
                            await requestMediaWithOptions(result, seasons: seasons, is4k: is4k)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.results) { result in
                    SearchResultCard(
                        result: result,
                        onViewDetails: { selectedResult = result },
                        onRequest: { handleRequestAction(result) }
                    )
                    .onTapGesture {
                        selectedResult = result
                    }
                    .onAppear {
                        if result == viewModel.results.last {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
                }
            }
            .padding()

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            }
        }
    }

    // MARK: - Actions

    private func handleRequestAction(_ result: SearchResult) {
        // For TV shows, show options sheet for season selection
        if result.mediaType == .tvShow {
            requestOptionsResult = result
            showRequestOptions = true
            Task {
                await viewModel.loadTVDetails(tmdbId: result.id)
            }
        } else {
            // For movies, either show options if 4K is available, or request directly
            if viewModel.canRequest4K {
                requestOptionsResult = result
                showRequestOptions = true
            } else {
                Task {
                    await requestMedia(result)
                }
            }
        }
    }

    private func requestMedia(_ result: SearchResult) async {
        isRequestingMedia = true

        do {
            try await viewModel.requestMedia(result)
            showRequestSuccess = true
            selectedResult = nil
        } catch {
            requestError = error.localizedDescription
        }

        isRequestingMedia = false
    }

    private func requestMediaWithOptions(
        _ result: SearchResult,
        seasons: [Int]?,
        is4k: Bool
    ) async {
        isRequestingMedia = true
        showRequestOptions = false

        do {
            try await viewModel.requestMediaWithOptions(result, seasons: seasons, is4k: is4k)
            showRequestSuccess = true
            selectedResult = nil
            requestOptionsResult = nil
        } catch {
            requestError = error.localizedDescription
        }

        isRequestingMedia = false
        viewModel.clearTVDetails()
    }
}

// MARK: - GenreBrowseViewModel

@MainActor
final class GenreBrowseViewModel: ObservableObject, RequestOptionsProvider {
    // MARK: - Published Properties

    @Published var results: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1

    // TV Details for season selection
    @Published var tvDetails: TVDetails?
    @Published var isLoadingTVDetails: Bool = false

    // MARK: - Private Properties

    private let genre: DiscoverGenre
    private let mediaType: MediaTypeBadge.MediaType
    private var jellyseerrService: JellyseerrService?
    private let appState: AppState

    // MARK: - Initialization

    init(genre: DiscoverGenre, mediaType: MediaTypeBadge.MediaType, appState: AppState) {
        self.genre = genre
        self.mediaType = mediaType
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

    func loadInitial() async {
        guard let service = jellyseerrService else {
            errorMessage = "Jellyseerr not configured"
            return
        }

        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let response: DiscoverResponse
            if mediaType == .movie {
                response = try await service.getMoviesByGenre(genreId: genre.id, page: 1)
            } else {
                response = try await service.getTVByGenre(genreId: genre.id, page: 1)
            }

            results = response.results
            totalPages = response.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard let service = jellyseerrService,
              currentPage < totalPages,
              !isLoadingMore
        else {
            return
        }

        isLoadingMore = true
        currentPage += 1

        do {
            let response: DiscoverResponse
            if mediaType == .movie {
                response = try await service.getMoviesByGenre(genreId: genre.id, page: currentPage)
            } else {
                response = try await service.getTVByGenre(genreId: genre.id, page: currentPage)
            }

            results.append(contentsOf: response.results)
        } catch {
            currentPage -= 1
            print("Failed to load more: \(error)")
        }

        isLoadingMore = false
    }

    // MARK: - TV Details

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

    func clearTVDetails() {
        tvDetails = nil
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

    var canRequest4K: Bool {
        appState.canRequest4K
    }

    var hasSeasons: Bool {
        guard let details = tvDetails,
              let seasons = details.seasons
        else {
            return false
        }
        return !seasons.isEmpty
    }

    var availableSeasons: [TVDetails.Season] {
        tvDetails?.seasons?.filter { $0.seasonNumber > 0 } ?? []
    }
}
