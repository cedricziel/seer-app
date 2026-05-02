import JellyseerrClient
import Kingfisher
import SeerCore
import SeerUI
import SwiftUI

/// View for discovering trending, upcoming, and genre-based content via Jellyseerr
struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        DiscoverContentView(appState: appState)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct DiscoverContentView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: DiscoverViewModel

    @State private var selectedResult: SearchResult?
    @State private var isRequestingMedia: Bool = false
    @State private var requestError: String?
    @State private var showRequestSuccess: Bool = false

    // Request options
    @State private var showRequestOptions: Bool = false
    @State private var requestOptionsResult: SearchResult?

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: DiscoverViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isJellyseerrConfigured {
                    notConfiguredView
                } else if viewModel.isLoading, !viewModel.hasContent {
                    LoadingView(message: "Loading...")
                } else if let error = viewModel.errorMessage, !viewModel.hasContent {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    discoverContentView
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSwitcherButton()
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
        .task {
            if !viewModel.hasContent {
                await viewModel.loadInitialData()
            }
        }
        .onChange(of: appState.activeServerID) {
            viewModel.serverChanged()
        }
    }

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        JellyseerrConnectPrompt(
            title: "Discover Movies & Shows",
            description: "Connect Jellyseerr to browse trending content and request new media.",
            onSuccess: {
                Task {
                    viewModel.serverChanged()
                    await viewModel.loadInitialData()
                }
            }
        )
    }

    // MARK: - Discover Content

    private var discoverContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Trending
                if viewModel.isLoadingTrending {
                    SkeletonCardRow(title: "Trending", cardCount: 5, cardWidth: 140)
                } else if !viewModel.trending.isEmpty {
                    trendingSection
                }

                // Upcoming Movies
                if viewModel.isLoadingUpcomingMovies {
                    SkeletonCardRow(title: "Upcoming Movies", cardCount: 5, cardWidth: 140)
                } else if !viewModel.upcomingMovies.isEmpty {
                    upcomingMoviesSection
                }

                // Upcoming TV Shows
                if viewModel.isLoadingUpcomingTV {
                    SkeletonCardRow(title: "Upcoming TV Shows", cardCount: 5, cardWidth: 140)
                } else if !viewModel.upcomingTV.isEmpty {
                    upcomingTVSection
                }

                // Movie Genres
                if viewModel.isLoadingGenres {
                    SkeletonCardRow(title: "Movie Genres", cardCount: 4, cardWidth: 200, aspectRatio: 16 / 9)
                } else if !viewModel.movieGenres.isEmpty {
                    movieGenresSection
                }

                // TV Genres
                if !viewModel.isLoadingGenres, !viewModel.tvGenres.isEmpty {
                    tvGenresSection
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Content Sections

    private var trendingSection: some View {
        MediaCardRow(title: "Trending") {
            ForEach(viewModel.trending) { result in
                searchResultCard(for: result)
            }
        }
    }

    private var upcomingMoviesSection: some View {
        MediaCardRow(title: "Upcoming Movies") {
            ForEach(viewModel.upcomingMovies) { result in
                searchResultCard(for: result)
            }
        }
    }

    private var upcomingTVSection: some View {
        MediaCardRow(title: "Upcoming TV Shows") {
            ForEach(viewModel.upcomingTV) { result in
                searchResultCard(for: result)
            }
        }
    }

    private var movieGenresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movie Genres")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.movieGenres) { genre in
                        NavigationLink(value: GenreDestination(genre: genre, mediaType: .movie)) {
                            genreCard(for: genre)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationDestination(for: GenreDestination.self) { destination in
            GenreBrowseView(
                genre: destination.genre,
                mediaType: destination.mediaType,
                appState: appState
            )
        }
    }

    private var tvGenresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TV Genres")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.tvGenres) { genre in
                        NavigationLink(value: GenreDestination(genre: genre, mediaType: .tvShow)) {
                            genreCard(for: genre)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Card Views

    private func searchResultCard(for result: SearchResult) -> some View {
        Button {
            selectedResult = result
        } label: {
            SearchResultCard(
                result: result,
                onViewDetails: { selectedResult = result },
                onRequest: { handleRequestAction(result) }
            )
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }

    private func genreCard(for genre: DiscoverGenre) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            if let url = genre.backdropURL() {
                KFImage(url)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(width: 200, height: 112)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 112)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Genre name
            Text(genre.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(12)
        }
        .frame(width: 200, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(genre.name) genre")
        .accessibilityAddTraits(.isButton)
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

// MARK: - Supporting Types

/// Navigation destination for genre browsing
struct GenreDestination: Hashable {
    let genre: DiscoverGenre
    let mediaType: MediaTypeBadge.MediaType
}

#Preview {
    DiscoverView()
        .environmentObject(AppState())
}
