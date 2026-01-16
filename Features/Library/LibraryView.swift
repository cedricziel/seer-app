import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

/// Main library browsing view
struct LibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LibraryContentView(appState: appState)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct LibraryContentView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: LibraryViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: LibraryViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading, viewModel.mediaItems.isEmpty, viewModel.continueWatching.isEmpty {
                    LoadingView(message: "Loading library...")
                } else if let error = viewModel.errorMessage, viewModel.mediaItems.isEmpty {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else {
                    contentView
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(item: item, source: .library, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSwitcherButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(LibraryViewModel.MediaTypeFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                viewModel.selectedMediaType = filter
                                Task {
                                    await viewModel.filterChanged()
                                }
                            }, label: {
                                HStack {
                                    Text(filter.rawValue)
                                    if viewModel.selectedMediaType == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            })
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onDisappear {
            viewModel.cancelAllTasks()
        }
        .onChange(of: appState.activeServerID) {
            // Cancel existing tasks before refreshing for new server
            viewModel.cancelAllTasks()
            Task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Continue Watching Section
                if viewModel.isLoadingContinueWatching {
                    SkeletonCardRow(title: "Continue Watching", cardCount: 4, cardWidth: 140)
                } else if !viewModel.continueWatching.isEmpty {
                    continueWatchingSection
                }

                // Latest Items Section
                if viewModel.isLoadingLatestItems {
                    SkeletonCardRow(title: "Recently Added", cardCount: 5, cardWidth: 140)
                } else if !viewModel.latestItems.isEmpty {
                    latestItemsSection
                } else if viewModel.hasLoadedLatestItems {
                    recentlyAddedEmptySection
                }

                // Libraries Section
                if !viewModel.libraries.isEmpty {
                    librariesSection
                }

                // All Media Grid
                if viewModel.selectedLibrary != nil || viewModel.selectedMediaType != .all {
                    mediaGridSection
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Continue Watching

    private var continueWatchingSection: some View {
        MediaCardRow(title: "Continue Watching") {
            ForEach(viewModel.continueWatching) { item in
                NavigationLink(value: item) {
                    MediaCard(
                        title: item.name,
                        subtitle: item.seriesName ?? item.formattedRuntime,
                        imageURL: viewModel.imageURL(for: item)
                    )
                    .frame(width: 140)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Latest Items

    private var latestItemsSection: some View {
        MediaCardRow(title: "Recently Added") {
            ForEach(viewModel.latestItems) { item in
                NavigationLink(value: item) {
                    MediaCard(
                        title: item.name,
                        subtitle: item.year.map { String($0) },
                        imageURL: viewModel.imageURL(for: item)
                    )
                    .frame(width: 140)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentlyAddedEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            SectionEmptyView(message: "No recent additions", systemImage: "film.stack")
        }
    }

    // MARK: - Libraries

    private var librariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Libraries")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.libraries) { library in
                        Button(action: {
                            Task {
                                await viewModel.selectLibrary(library)
                            }
                        }, label: {
                            libraryCard(library)
                        })
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func libraryCard(_ library: Library) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 160, height: 90)
                .overlay {
                    Image(systemName: libraryIcon(for: library.collectionType))
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

            Text(library.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }

    private func libraryIcon(for type: Library.CollectionType?) -> String {
        switch type {
        case .movies: "film"
        case .tvshows: "tv"
        case .music: "music.note"
        case .books: "book"
        default: "folder"
        }
    }

    // MARK: - Media Grid

    private var mediaGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.selectedLibrary?.name ?? viewModel.selectedMediaType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if viewModel.selectedLibrary != nil {
                    Button("Clear") {
                        Task {
                            await viewModel.selectLibrary(nil)
                        }
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.mediaItems) { item in
                    NavigationLink(value: item) {
                        MediaCard(
                            title: item.name,
                            subtitle: item.year.map { String($0) },
                            imageURL: viewModel.imageURL(for: item)
                        )
                        .onAppear {
                            Task {
                                await viewModel.loadMoreItemsIfNeeded(currentItem: item)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            }
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
