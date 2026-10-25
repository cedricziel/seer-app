import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

struct LibrarySearchView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var model: LibrarySearchModel
    @StateObject private var detailModel: LibraryViewModel
    @Binding private var query: String
    @State private var retry = 0

    init(appState: AppState, query: Binding<String>) {
        _query = query
        _detailModel = StateObject(wrappedValue: LibraryViewModel(appState: appState))
        _model = StateObject(wrappedValue: Self.makeModel(appState: appState))
    }

    private static func makeModel(appState: AppState) -> LibrarySearchModel {
        let service = appState.jellyfinCredentials.map {
            JellyfinService(
                serverURL: $0.serverURL, accessToken: $0.accessToken,
                userID: $0.userId, deviceID: $0.deviceId
            )
        }
        return LibrarySearchModel { query, offset in
            guard let service else { throw JellyfinService.JellyfinError.notAuthenticated }
            return try await service.getItems(
                includeItemTypes: [.movie, .series], startIndex: offset, searchTerm: query
            )
        }
    }

    var body: some View {
        Group {
            if model.isSearching {
                LoadingView(message: "Searching library...")
            } else if let error = model.errorMessage, model.items.isEmpty {
                ErrorView(error: error) { retry += 1 }
            } else if !model.hasSearched {
                ContentUnavailableView(
                    "Search Your Library", systemImage: "magnifyingglass",
                    description: Text("Find movies and TV shows on your active server.")
                )
            } else if model.items.isEmpty {
                ContentUnavailableView(
                    "No Library Results", systemImage: "magnifyingglass",
                    description: Text("Try another title, or choose Catalog to find something to request.")
                )
            } else {
                results
            }
        }
        .searchable(text: $query, prompt: "Search your library")
        .task(id: SearchRequest(query: query, retry: retry)) {
            await model.search(query: query)
        }
        .onDisappear { model.cancel() }
        .navigationDestination(for: MediaItem.self) { item in
            MediaDetailView(item: item, source: .library, viewModel: detailModel)
        }
        .navigationDestination(for: MediaItem.Person.self) { person in
            PersonDetailView(person: person, appState: appState)
        }
    }

    private var results: some View {
        List {
            ForEach(model.items) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.type == .series ? "TV Show" : "Movie")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let year = item.year {
                            Text(String(year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if model.hasMore {
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                }
                Button {
                    Task { await model.loadMore() }
                } label: {
                    if model.isLoadingMore {
                        ProgressView("Loading more...")
                    } else {
                        Text(model.errorMessage == nil ? "Load More" : "Retry Loading More")
                    }
                }
                .disabled(model.isLoadingMore)
            }
        }
        .listStyle(.plain)
    }

    private struct SearchRequest: Equatable {
        let query: String
        let retry: Int
    }
}
