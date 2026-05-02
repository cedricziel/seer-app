import CoreSpotlight
@testable import SeerCore
import SwiftData
import XCTest

/// `CSSearchableIndex` test seam: a recording stub that captures
/// index/delete operations without touching the real system index.
private final class RecordingIndex: CSSearchableIndex, @unchecked Sendable {
    let lock = NSLock()
    private(set) var indexedItems: [CSSearchableItem] = []
    private(set) var deletedDomains: [[String]] = []

    override func indexSearchableItems(
        _ items: [CSSearchableItem],
        completionHandler: ((Error?) -> Void)? = nil
    ) {
        lock.lock()
        indexedItems.append(contentsOf: items)
        lock.unlock()
        completionHandler?(nil)
    }

    override func deleteSearchableItems(
        withDomainIdentifiers domainIdentifiers: [String],
        completionHandler: ((Error?) -> Void)? = nil
    ) {
        lock.lock()
        deletedDomains.append(domainIdentifiers)
        lock.unlock()
        completionHandler?(nil)
    }
}

@MainActor
final class SpotlightIndexerTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var index: RecordingIndex!
    private var serverID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            ServerConfiguration.self,
            CachedLibrary.self,
            CachedMediaItem.self,
            CachedUserProgress.self,
            CachedRequest.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
        appState = AppState()
        appState.setModelContext(container.mainContext)
        appState.appIntentsIndexingEnabled = false
        index = RecordingIndex(name: "test-index")
        serverID = UUID()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(
            forKey: AppState.AppIntentsKeys.indexingEnabled
        )
        container = nil
        appState = nil
        index = nil
        serverID = nil
        try await super.tearDown()
    }

    private func makeIndexer() -> SpotlightIndexer {
        SpotlightIndexer(
            appState: appState,
            modelContainer: container,
            searchableIndex: index
        )
    }

    private func insertItems(_ count: Int, prefix: String = "item") throws {
        let context = container.mainContext
        for idx in 0 ..< count {
            context.insert(CachedMediaItem(
                id: "\(prefix)-\(idx)",
                serverConfigurationID: serverID,
                name: "\(prefix.capitalized) \(idx)",
                year: 2024,
                mediaType: "Movie"
            ))
        }
        try context.save()
    }

    /// 6.3 — When the flag is on, indexer registers all cached items.
    func testIndexesWhenFlagEnabled() async throws {
        try insertItems(3)
        appState.appIntentsIndexingEnabled = true
        let indexer = makeIndexer()
        await indexer.rebuildIndex()

        XCTAssertEqual(index.indexedItems.count, 3)
        XCTAssertTrue(index.deletedDomains.contains([SpotlightIndexer.domainIdentifier]))
    }

    /// 6.4 — When the flag is off, indexer purges and indexes nothing.
    func testRemovesIndexWhenFlagDisabled() async throws {
        try insertItems(3)
        // Flag off (default in setUp).
        let indexer = makeIndexer()
        await indexer.rebuildIndex()

        XCTAssertEqual(index.indexedItems.count, 0)
        XCTAssertTrue(index.deletedDomains.contains([SpotlightIndexer.domainIdentifier]))
    }

    /// 6.5 — Indexer reflects new items on each rebuild call. The
    /// recording stub accumulates across calls, so after two rebuilds
    /// we expect total = first batch + second batch.
    func testReindexesAfterOfflineSyncRefresh() async throws {
        try insertItems(2, prefix: "first")
        appState.appIntentsIndexingEnabled = true
        let indexer = makeIndexer()
        await indexer.rebuildIndex()
        XCTAssertEqual(index.indexedItems.count, 2)

        try insertItems(3, prefix: "second")
        await indexer.rebuildIndex()
        // First rebuild registered 2; second registered 5 (cumulative
        // count of the cache: 2 first + 3 second).
        XCTAssertEqual(index.indexedItems.count, 2 + 5)
    }
}
