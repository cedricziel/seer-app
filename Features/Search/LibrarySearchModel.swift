import Foundation
import JellyfinClient
import SwiftUI

@MainActor
final class LibrarySearchModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasSearched = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?

    private let loader: @MainActor (String, Int) async throws -> ItemsResponse
    private let debounceMilliseconds: Int
    private var generation = 0
    private var query = ""
    private var completedQuery: String?

    init(
        debounceMilliseconds: Int = 300,
        loader: @escaping @MainActor (String, Int) async throws -> ItemsResponse
    ) {
        self.debounceMilliseconds = debounceMilliseconds
        self.loader = loader
    }

    func search(query: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard completedQuery != query else { return }
        generation += 1
        let currentGeneration = generation
        defer {
            if generation == currentGeneration {
                isSearching = false
            }
        }
        self.query = query
        completedQuery = nil
        items = []
        hasMore = false
        errorMessage = nil
        isLoadingMore = false
        hasSearched = !self.query.isEmpty
        isSearching = hasSearched
        guard hasSearched else { return }

        do {
            if debounceMilliseconds > 0 {
                try await Task.sleep(for: .milliseconds(debounceMilliseconds))
            }
            try Task.checkCancellation()
            guard generation == currentGeneration else { return }
            let response = try await loader(self.query, 0)
            guard generation == currentGeneration, !Task.isCancelled else { return }
            items = response.items
            hasMore = !response.items.isEmpty && items.count < response.totalRecordCount
            completedQuery = query
        } catch {
            guard generation == currentGeneration else { return }
            if !Task.isCancelled, !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isSearching, !isLoadingMore else { return }
        let currentGeneration = generation
        defer {
            if generation == currentGeneration {
                isLoadingMore = false
            }
        }
        isLoadingMore = true
        errorMessage = nil
        do {
            let response = try await loader(query, items.count)
            guard generation == currentGeneration, !Task.isCancelled else { return }
            items.append(contentsOf: response.items)
            hasMore = !response.items.isEmpty && items.count < response.totalRecordCount
        } catch {
            guard generation == currentGeneration else { return }
            if !Task.isCancelled, !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        generation += 1
        isSearching = false
        isLoadingMore = false
    }
}
