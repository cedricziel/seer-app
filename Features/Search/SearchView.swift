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
                    onRequest: {
                        Task {
                            await requestMedia(result)
                        }
                    },
                    isRequesting: isRequestingMedia
                )
                .presentationDetents([.medium, .large])
            }
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
        if viewModel.isSearching, viewModel.searchResults.isEmpty {
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
            EmptyContentView(
                title: "Search TMDB",
                systemImage: "magnifyingglass",
                description: "Search for movies and TV shows to request"
            )
        } else {
            searchResultsGrid
        }
    }

    // MARK: - Search Results Grid

    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 16),
            ], spacing: 16) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultCard(result: result)
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
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            ZStack(alignment: .topTrailing) {
                PosterImage(url: result.posterURL())

                // Status indicator
                if result.isAvailable {
                    RequestStatusBadge(status: .available, style: .compact)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                } else if result.hasPendingRequest {
                    RequestStatusBadge(status: .pending, style: .compact)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let year = result.displayYear {
                        Text(year)
                    }

                    MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tv)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Search Result Detail Sheet

struct SearchResultDetailSheet: View {
    let result: SearchResult
    let onRequest: () -> Void
    let isRequesting: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top, spacing: 16) {
                        PosterImage(url: result.posterURL())
                            .frame(width: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                if let year = result.displayYear {
                                    Text(year)
                                }

                                MediaTypeBadge(type: result.mediaType == .movie ? .movie : .tv)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            if let rating = result.voteAverage, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                            }

                            // Status
                            if result.isAvailable {
                                RequestStatusBadge(status: .available, style: .full)
                            } else if result.hasPendingRequest {
                                RequestStatusBadge(status: .pending, style: .full)
                            }
                        }
                    }

                    // Overview
                    if let overview = result.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)

                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Request Button
                    if !result.isAvailable, !result.hasPendingRequest {
                        Button(action: onRequest) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text(isRequesting ? "Requesting..." : "Request")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isRequesting)
                    } else if result.isAvailable {
                        Label("Already Available", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Label("Already Requested", systemImage: "clock")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
}
