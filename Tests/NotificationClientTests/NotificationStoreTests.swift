@testable import NotificationClient
import SwiftData
import XCTest

/// Regression coverage for `NotificationStore`. The store previously fetched
/// a row on one `ModelContext` and saved a different one, so status updates
/// were silently dropped and the poller re-notified the same change forever.
final class NotificationStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: NotificationStore!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([NotificationPreferences.self, CachedRequestStatus.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        store = NotificationStore(modelContainer: container)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Cached request status

    func testUpsert_updatesExistingRowInPlace() async throws {
        try await store.upsertCachedStatus(
            requestID: 12, status: 1, mediaTitle: "Movie", mediaType: "movie", serverID: "A"
        )
        try await store.upsertCachedStatus(
            requestID: 12, status: 2, mediaTitle: "Movie", mediaType: "movie", serverID: "A"
        )

        let all = try await store.fetchAllCachedStatuses(forServerID: "A")
        XCTAssertEqual(all.count, 1, "Second upsert must update, not insert")
        XCTAssertEqual(all.first?.status, 2, "Updated status must persist")

        let single = try await store.fetchCachedStatus(requestID: 12, serverID: "A")
        XCTAssertEqual(single?.status, 2)
    }

    func testUpsert_isScopedPerServer() async throws {
        try await store.upsertCachedStatus(
            requestID: 12, status: 1, mediaTitle: "On A", mediaType: "movie", serverID: "A"
        )
        try await store.upsertCachedStatus(
            requestID: 12, status: 4, mediaTitle: "On B", mediaType: "tv", serverID: "B"
        )

        let onA = try await store.fetchCachedStatus(requestID: 12, serverID: "A")
        let onB = try await store.fetchCachedStatus(requestID: 12, serverID: "B")
        XCTAssertEqual(onA?.status, 1)
        XCTAssertEqual(onA?.mediaTitle, "On A")
        XCTAssertEqual(onB?.status, 4)
        XCTAssertEqual(onB?.mediaTitle, "On B")

        let allA = try await store.fetchAllCachedStatuses(forServerID: "A")
        XCTAssertEqual(allA.map(\.serverID), ["A"])
    }

    func testDelete_removesOnlyThatServersRow() async throws {
        try await store.upsertCachedStatus(
            requestID: 1, status: 1, mediaTitle: "x", mediaType: "movie", serverID: "A"
        )
        try await store.upsertCachedStatus(
            requestID: 1, status: 1, mediaTitle: "x", mediaType: "movie", serverID: "B"
        )

        try await store.deleteCachedStatus(requestID: 1, serverID: "A")

        let onA = try await store.fetchCachedStatus(requestID: 1, serverID: "A")
        let onB = try await store.fetchCachedStatus(requestID: 1, serverID: "B")
        XCTAssertNil(onA)
        XCTAssertNotNil(onB)
    }

    func testDeleteAll_clearsServer() async throws {
        for id in 1 ... 3 {
            try await store.upsertCachedStatus(
                requestID: id, status: 1, mediaTitle: "x", mediaType: "movie", serverID: "A"
            )
        }
        try await store.upsertCachedStatus(
            requestID: 9, status: 1, mediaTitle: "x", mediaType: "movie", serverID: "B"
        )

        try await store.deleteAllCachedStatuses(forServerID: "A")

        let onA = try await store.fetchAllCachedStatuses(forServerID: "A")
        let onB = try await store.fetchAllCachedStatuses(forServerID: "B")
        XCTAssertTrue(onA.isEmpty)
        XCTAssertEqual(onB.count, 1)
    }

    // MARK: - Preferences

    func testPreferences_defaultToEnabledWhenNothingStored() async throws {
        let prefs = try await store.fetchPreferences()
        XCTAssertEqual(prefs, NotificationPreferenceValues())
        XCTAssertTrue(prefs.requestApprovedEnabled)
    }

    func testPreferences_roundTrip() async throws {
        var prefs = try await store.fetchPreferences()
        prefs.requestApprovedEnabled = false
        prefs.downloadFailureEnabled = false
        try await store.savePreferences(prefs)

        let reloaded = try await store.fetchPreferences()
        XCTAssertEqual(reloaded, prefs)
        XCTAssertFalse(reloaded.requestApprovedEnabled)
        XCTAssertFalse(reloaded.downloadFailureEnabled)
        XCTAssertTrue(reloaded.requestAvailableEnabled)
    }

    func testPreferences_saveTwiceKeepsSingleRow() async throws {
        try await store.savePreferences(NotificationPreferenceValues(autoDownloadEnabled: false))
        try await store.savePreferences(NotificationPreferenceValues(autoDownloadEnabled: true))

        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<NotificationPreferences>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.first?.autoDownloadEnabled ?? false)
    }
}
