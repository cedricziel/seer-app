import JellyfinClient
@testable import SeerApp
import XCTest

@MainActor
final class LibrarySearchModelTests: XCTestCase {
    func testSearchReturnsLibraryMatchesWithoutJellyseerr() async {
        let model = LibrarySearchModel(debounceMilliseconds: 0) { query, _ in
            try Self.page(name: query, total: 1)
        }

        await model.search(query: "  Arrival  ")

        XCTAssertEqual(model.items.map(\.name), ["Arrival"])
        XCTAssertFalse(model.isSearching)
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.errorMessage)
    }

    func testBlankQueryClearsPreviousResults() async {
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, _ in
            try Self.page(name: "Arrival", total: 1)
        }
        await model.search(query: "Arrival")

        await model.search(query: " \n ")

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.hasSearched)
        XCTAssertFalse(model.isSearching)
    }

    func testFailureCanBeRetried() async {
        var shouldFail = true
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, _ in
            if shouldFail {
                throw URLError(.notConnectedToInternet)
            }
            return try Self.page(name: "Arrival", total: 1)
        }
        await model.search(query: "Arrival")
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isSearching)

        shouldFail = false
        await model.search(query: "Arrival")

        XCTAssertEqual(model.items.map(\.name), ["Arrival"])
        XCTAssertNil(model.errorMessage)
    }

    func testOlderResponseCannotReplaceNewerQuery() async throws {
        let pending = PendingLibrarySearch()
        let model = LibrarySearchModel(debounceMilliseconds: 0) { query, _ in
            if query == "old" {
                return try await pending.response()
            }
            return try Self.page(name: "New", total: 1)
        }
        let oldSearch = Task { await model.search(query: "old") }
        await pending.waitUntilRequested()
        await model.search(query: "new")

        try pending.complete(with: Self.page(name: "Old", total: 1))
        await oldSearch.value

        XCTAssertEqual(model.items.map(\.name), ["New"])
        XCTAssertNil(model.errorMessage)
    }

    func testCancelledResponseCannotPopulateResults() async throws {
        let pending = PendingLibrarySearch()
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, _ in
            try await pending.response()
        }
        let search = Task { await model.search(query: "Arrival") }
        await pending.waitUntilRequested()

        model.cancel()
        try pending.complete(with: Self.page(name: "Arrival", total: 1))
        await search.value

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isSearching)
        XCTAssertNil(model.errorMessage)
    }

    func testLoadMoreAppendsNextPage() async {
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, offset in
            try Self.page(name: offset == 0 ? "First" : "Second", total: 2)
        }
        await model.search(query: "film")
        XCTAssertTrue(model.hasMore)

        await model.loadMore()

        XCTAssertEqual(model.items.map(\.name), ["First", "Second"])
        XCTAssertFalse(model.hasMore)
    }

    func testFailedPageKeepsResultsAndCanBeRetried() async {
        var failNextPage = true
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, offset in
            if offset > 0, failNextPage {
                throw URLError(.timedOut)
            }
            return try Self.page(name: offset == 0 ? "First" : "Second", total: 2)
        }
        await model.search(query: "film")
        await model.loadMore()
        XCTAssertEqual(model.items.map(\.name), ["First"])
        XCTAssertNotNil(model.errorMessage)

        failNextPage = false
        await model.loadMore()

        XCTAssertEqual(model.items.map(\.name), ["First", "Second"])
        XCTAssertNil(model.errorMessage)
    }

    func testReturningToCompletedQueryPreservesLoadedPages() async {
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, offset in
            try Self.page(name: offset == 0 ? "First" : "Second", total: 2)
        }
        await model.search(query: "film")
        await model.loadMore()
        model.cancel()

        await model.search(query: "film")

        XCTAssertEqual(model.items.map(\.name), ["First", "Second"])
        XCTAssertFalse(model.hasMore)
    }

    func testTaskCancellationSettlesSearchEvenWhenLoaderReturnsSuccess() async throws {
        let pending = PendingLibrarySearch()
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, _ in
            try await pending.response()
        }
        let search = Task { await model.search(query: "Arrival") }
        await pending.waitUntilRequested()

        search.cancel()
        try pending.complete(with: Self.page(name: "Arrival", total: 1))
        await search.value

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isSearching)
        XCTAssertNil(model.errorMessage)
    }

    func testTaskCancellationSettlesPaginationAndAllowsRetry() async throws {
        let pending = PendingLibrarySearch()
        let model = LibrarySearchModel(debounceMilliseconds: 0) { _, offset in
            if offset == 0 {
                return try Self.page(name: "First", total: 2)
            }
            return try await pending.response()
        }
        await model.search(query: "film")
        let page = Task { await model.loadMore() }
        await pending.waitUntilRequested()

        page.cancel()
        try pending.complete(with: Self.page(name: "Second", total: 2))
        await page.value

        XCTAssertEqual(model.items.map(\.name), ["First"])
        XCTAssertFalse(model.isLoadingMore)
        XCTAssertTrue(model.hasMore)
        XCTAssertNil(model.errorMessage)
    }

    func testPageFromPreviousQueryCannotAppendToNewResults() async throws {
        let pending = PendingLibrarySearch()
        let model = LibrarySearchModel(debounceMilliseconds: 0) { query, offset in
            if offset > 0 {
                return try await pending.response()
            }
            return try Self.page(name: query, total: query == "old" ? 2 : 1)
        }
        await model.search(query: "old")
        let page = Task { await model.loadMore() }
        await pending.waitUntilRequested()
        await model.search(query: "new")

        try pending.complete(with: Self.page(name: "Old Page", total: 2))
        await page.value

        XCTAssertEqual(model.items.map(\.name), ["new"])
        XCTAssertFalse(model.isLoadingMore)
        XCTAssertFalse(model.hasMore)
    }

    private static func page(name: String, total: Int) throws -> ItemsResponse {
        let json = """
        {"Items":[{"Id":"\(name)","Name":"\(name)","Type":"Movie"}],"TotalRecordCount":\(total),"StartIndex":0}
        """
        return try JSONDecoder().decode(ItemsResponse.self, from: Data(json.utf8))
    }
}

@MainActor
private final class PendingLibrarySearch {
    private var continuation: CheckedContinuation<ItemsResponse, any Error>?
    private var requested: CheckedContinuation<Void, Never>?

    func response() async throws -> ItemsResponse {
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

    func complete(with response: ItemsResponse) {
        continuation?.resume(returning: response)
        continuation = nil
    }
}
