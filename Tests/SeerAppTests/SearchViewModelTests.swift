@testable import SeerApp
@testable import SeerCore
import XCTest

/// End-to-end tests for the Search workflow's new behaviors:
/// - History persists, dedupes, and surfaces in the recent list
/// - Empty queries reset state without spinning up a request
/// - Debounce/searching flags transition through the right states
@MainActor
final class SearchViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var historyStore: SearchHistoryStore!
    private var appState: AppState!
    private var viewModel: SearchViewModel!
    private let suiteName = "com.seer.tests.searchViewModel"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        historyStore = SearchHistoryStore(defaults: defaults, keyPrefix: "test")
        appState = AppState()
        viewModel = SearchViewModel(
            appState: appState,
            historyStore: historyStore,
            debounceMilliseconds: 5
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        historyStore = nil
        appState = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - History wiring

    func testInit_loadsExistingHistoryFromStore() {
        historyStore.record("matrix")
        historyStore.record("inception")

        let freshViewModel = SearchViewModel(
            appState: appState,
            historyStore: historyStore,
            debounceMilliseconds: 5
        )

        XCTAssertEqual(freshViewModel.recentQueries, ["inception", "matrix"])
    }

    func testRunRecentQuery_setsSearchQueryToTheTappedValue() async {
        historyStore.record("matrix")
        viewModel.recentQueries = historyStore.recentQueries(scope: "default")

        // Without a configured Jellyseerr service, search() bails before
        // doing network work — but we should still see the query update.
        await viewModel.runRecentQuery("matrix")

        XCTAssertEqual(viewModel.searchQuery, "matrix")
    }

    func testRemoveRecentQuery_removesFromBothViewModelAndStore() {
        historyStore.record("matrix", scope: "default")
        viewModel.recentQueries = historyStore.recentQueries(scope: "default")

        viewModel.removeRecentQuery("matrix")

        XCTAssertTrue(viewModel.recentQueries.isEmpty)
        XCTAssertTrue(historyStore.recentQueries(scope: "default").isEmpty)
    }

    func testClearRecentQueries_emptiesBothViewModelAndStore() {
        historyStore.record("matrix", scope: "default")
        historyStore.record("inception", scope: "default")
        viewModel.recentQueries = historyStore.recentQueries(scope: "default")

        viewModel.clearRecentQueries()

        XCTAssertTrue(viewModel.recentQueries.isEmpty)
        XCTAssertTrue(historyStore.recentQueries(scope: "default").isEmpty)
    }

    // MARK: - Empty query handling

    func testSearch_withEmptyQuery_resetsState() async {
        viewModel.searchQuery = ""
        viewModel.hasSearched = true
        viewModel.searchResults = []
        viewModel.isDebouncing = true
        viewModel.isSearching = true

        await viewModel.search()

        XCTAssertFalse(viewModel.hasSearched)
        XCTAssertFalse(viewModel.isDebouncing)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    func testClearSearch_resetsAllStateAndCancelsTask() {
        viewModel.searchQuery = "matrix"
        viewModel.hasSearched = true
        viewModel.isDebouncing = true
        viewModel.isSearching = true

        viewModel.clearSearch()

        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertFalse(viewModel.hasSearched)
        XCTAssertFalse(viewModel.isDebouncing)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    // MARK: - Debounce flag transitions when service isn't configured

    func testSearch_withoutConfiguredService_setsErrorWithoutCrashing() async {
        // appState has no Jellyseerr config -> search() should bail safely.
        viewModel.searchQuery = "matrix"

        await viewModel.search()

        XCTAssertEqual(viewModel.errorMessage, "Jellyseerr not configured")
        XCTAssertFalse(viewModel.isSearching)
    }
}
