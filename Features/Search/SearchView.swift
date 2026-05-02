import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// View for searching TMDB and requesting media via Jellyseerr
struct SearchView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SearchContentView(appState: appState)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct SearchContentView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: SearchViewModel

    @State private var selectedResult: SearchResult?
    @State private var isRequestingMedia: Bool = false
    @State private var requestError: String?
    @State private var showRequestSuccess: Bool = false

    // Request options
    @State private var showRequestOptions: Bool = false
    @State private var requestOptionsResult: SearchResult?

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: SearchViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isJellyseerrConfigured {
                    notConfiguredView
                } else {
                    searchContentView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.searchQuery, prompt: "Search movies and TV shows")
            .onChange(of: viewModel.searchQuery) {
                Task {
                    await viewModel.search()
                }
            }
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
                    RequestOptionsSheet(
                        result: result,
                        viewModel: viewModel,
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
        .onChange(of: appState.activeServerID) {
            viewModel.serverChanged()
        }
    }

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        EmptyContentView(
            title: "Jellyseerr Not Configured",
            systemImage: "server.rack",
            description: "Configure Jellyseerr in settings to search and request media."
        )
    }

    // MARK: - Search Content

    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.isDebouncing, viewModel.searchResults.isEmpty {
            VStack {
                searchProgressBanner
                Spacer()
            }
        } else if viewModel.isSearching, viewModel.searchResults.isEmpty {
            LoadingView(message: "Searching...")
        } else if let error = viewModel.errorMessage {
            ErrorView(error: error) {
                Task {
                    await viewModel.search()
                }
            }
        } else if viewModel.hasSearched, viewModel.searchResults.isEmpty {
            EmptyContentView(
                title: "No Results",
                systemImage: "magnifyingglass",
                description: "Try searching for something else"
            )
        } else if !viewModel.hasSearched {
            searchEmptyState
        } else {
            VStack(spacing: 0) {
                searchProgressBanner
                searchResultsGrid
            }
        }
    }

    @ViewBuilder
    private var searchEmptyState: some View {
        if viewModel.recentQueries.isEmpty {
            EmptyContentView(
                title: "Search TMDB",
                systemImage: "magnifyingglass",
                description: "Search for movies and TV shows to request"
            )
        } else {
            recentQueriesList
        }
    }

    private var recentQueriesList: some View {
        List {
            Section {
                ForEach(viewModel.recentQueries, id: \.self) { query in
                    Button {
                        Task { await viewModel.runRecentQuery(query) }
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(query)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Search again for \(query)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeRecentQuery(query)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button("Clear") {
                        viewModel.clearRecentQueries()
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("search.clearRecents")
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("search.recentQueries")
    }

    @ViewBuilder
    private var searchProgressBanner: some View {
        if viewModel.isDebouncing || viewModel.isSearching {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)
                Text(viewModel.isDebouncing ? "Searching..." : "Loading more results...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .accessibilityIdentifier("search.progressBanner")
        }
    }

    // MARK: - Search Results Grid

    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultCard(
                        result: result,
                        onViewDetails: { selectedResult = result },
                        onRequest: { handleRequestAction(result) }
                    )
                    .onTapGesture {
                        selectedResult = result
                    }
                    .onAppear {
                        if result == viewModel.searchResults.last {
                            Task {
                                await viewModel.loadMoreResults()
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

#Preview {
    SearchView()
        .environmentObject(AppState())
}
