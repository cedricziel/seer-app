import JellyseerrClient
@testable import SeerApp
import SeerCore
import XCTest

@MainActor
final class CatalogSearchPaginationTests: XCTestCase {
    func testPreviousQueryPageCannotAppendToNewResults() async throws {
        let pending = PendingCatalogPage()
        let model = makeModel(pending: pending)
        model.searchQuery = "old"
        await model.search()
        let page = Task { await model.loadMoreResults() }
        await pending.waitUntilRequested()

        model.searchQuery = "new"
        await model.search()
        try pending.complete(.success(Self.response(title: "Old Page", page: 2)))
        await page.value

        XCTAssertEqual(model.searchResults.map(\.displayTitle), ["new"])
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertFalse(model.isLoadingMore)
    }

    func testFailedPreviousQueryPageCannotChangeNewPageNumber() async {
        let pending = PendingCatalogPage()
        let model = makeModel(pending: pending)
        model.searchQuery = "old"
        await model.search()
        let page = Task { await model.loadMoreResults() }
        await pending.waitUntilRequested()

        model.searchQuery = "new"
        await model.search()
        pending.complete(.failure(URLError(.timedOut)))
        await page.value

        XCTAssertEqual(model.currentPage, 1)
        XCTAssertEqual(model.searchResults.map(\.displayTitle), ["new"])
        XCTAssertNil(model.errorMessage)
    }

    func testClearedSearchRejectsPendingPageAndResetsPagination() async throws {
        let pending = PendingCatalogPage()
        let model = makeModel(pending: pending)
        model.searchQuery = "old"
        await model.search()
        let page = Task { await model.loadMoreResults() }
        await pending.waitUntilRequested()

        model.clearSearch()
        try pending.complete(.success(Self.response(title: "Old Page", page: 2)))
        await page.value

        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertEqual(model.totalPages, 1)
        XCTAssertFalse(model.isLoadingMore)
    }

    func testServerChangeRejectsPendingPage() async throws {
        let pending = PendingCatalogPage()
        let model = makeModel(pending: pending)
        model.searchQuery = "old"
        await model.search()
        let page = Task { await model.loadMoreResults() }
        await pending.waitUntilRequested()

        model.serverChanged()
        try pending.complete(.success(Self.response(title: "Old Server", page: 2)))
        await page.value

        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertFalse(model.isLoadingMore)
    }

    func testCurrentQueryPageAppendsAndAdvancesPagination() async throws {
        let pending = PendingCatalogPage()
        let model = makeModel(pending: pending)
        model.searchQuery = "film"
        await model.search()
        let page = Task { await model.loadMoreResults() }
        await pending.waitUntilRequested()

        try pending.complete(.success(Self.response(title: "Second", page: 2)))
        await page.value

        XCTAssertEqual(model.searchResults.map(\.displayTitle), ["film", "Second"])
        XCTAssertEqual(model.currentPage, 2)
        XCTAssertFalse(model.isLoadingMore)
    }

    private func makeModel(pending: PendingCatalogPage) -> SearchViewModel {
        let suite = "CatalogSearchPaginationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return SearchViewModel(
            appState: AppState(),
            historyStore: SearchHistoryStore(defaults: defaults),
            debounceMilliseconds: 0
        ) { query, page in
            if page > 1 {
                return try await pending.response()
            }
            return try Self.response(title: query)
        }
    }

    private static func response(title: String, page: Int = 1) throws -> SearchResponse {
        let json = """
        {"page":\(page),"totalPages":3,"totalResults":3,
        "results":[{"id":\(page),"mediaType":"movie","title":"\(title)"}]}
        """
        return try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))
    }
}

@MainActor
private final class PendingCatalogPage {
    private var continuation: CheckedContinuation<SearchResponse, any Error>?
    private var requested: CheckedContinuation<Void, Never>?

    func response() async throws -> SearchResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            requested?.resume()
            requested = nil
        }
    }

    func waitUntilRequested() async {
        if continuation != nil {
            return
        }
        await withCheckedContinuation { requested = $0 }
    }

    func complete(_ result: Result<SearchResponse, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
