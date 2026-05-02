@testable import SeerCore
import XCTest

final class SearchHistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SearchHistoryStore!
    private let suiteName = "com.seer.tests.searchHistory"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SearchHistoryStore(defaults: defaults, keyPrefix: "test")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Recording

    func testRecord_addsQueryToFront() {
        store.record("matrix")
        store.record("inception")
        XCTAssertEqual(store.recentQueries(), ["inception", "matrix"])
    }

    func testRecord_dedupesCaseInsensitively() {
        store.record("Matrix")
        store.record("the matrix")
        store.record("MATRIX")

        let recent = store.recentQueries()
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first, "MATRIX", "Latest casing should win and move to the top")
        XCTAssertEqual(recent.last, "the matrix")
    }

    func testRecord_trimsWhitespace() {
        store.record("  matrix  ")
        XCTAssertEqual(store.recentQueries(), ["matrix"])
    }

    func testRecord_skipsEmptyAndShortQueries() {
        store.record("")
        store.record(" ")
        store.record("a")
        XCTAssertTrue(store.recentQueries().isEmpty)
    }

    func testRecord_capsAtMaxItems() {
        for index in 1 ... (SearchHistoryStore.maxItems + 5) {
            store.record("query\(index)")
        }
        let recent = store.recentQueries()
        XCTAssertEqual(recent.count, SearchHistoryStore.maxItems)
        XCTAssertEqual(recent.first, "query\(SearchHistoryStore.maxItems + 5)")
    }

    // MARK: - Removal & Clear

    func testRemove_removesMatchingQuery() {
        store.record("matrix")
        store.record("inception")
        store.remove("matrix")
        XCTAssertEqual(store.recentQueries(), ["inception"])
    }

    func testRemove_isCaseInsensitive() {
        store.record("Matrix")
        store.remove("MATRIX")
        XCTAssertTrue(store.recentQueries().isEmpty)
    }

    func testClear_removesAllQueries() {
        store.record("matrix")
        store.record("inception")
        store.clear()
        XCTAssertTrue(store.recentQueries().isEmpty)
    }

    // MARK: - Scoping

    func testScopes_areIsolated() {
        store.record("matrix", scope: "serverA")
        store.record("inception", scope: "serverB")

        XCTAssertEqual(store.recentQueries(scope: "serverA"), ["matrix"])
        XCTAssertEqual(store.recentQueries(scope: "serverB"), ["inception"])
    }

    func testClear_onlyAffectsTargetScope() {
        store.record("matrix", scope: "serverA")
        store.record("inception", scope: "serverB")
        store.clear(scope: "serverA")

        XCTAssertTrue(store.recentQueries(scope: "serverA").isEmpty)
        XCTAssertEqual(store.recentQueries(scope: "serverB"), ["inception"])
    }

    // MARK: - Persistence

    func testRecord_persistsAcrossInstances() {
        store.record("matrix")
        let secondStore = SearchHistoryStore(defaults: defaults, keyPrefix: "test")
        XCTAssertEqual(secondStore.recentQueries(), ["matrix"])
    }
}
