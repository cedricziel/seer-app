@testable import SeerCore
import SwiftData
import XCTest

/// Covers the AppEntity foundation: `MediaItemEntityQuery`,
/// `RequestEntityQuery`, `ServerEntityQuery`. Tests use an in-memory
/// SwiftData container injected via `AppIntentsContext` so the
/// production CloudKit container is never touched.
@MainActor
final class AppEntityQueryTests: XCTestCase {
    // MARK: - Fixtures

    private var container: ModelContainer!
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
        serverID = UUID()

        AppIntentsContext.modelContainer = container
    }

    override func tearDown() async throws {
        AppIntentsContext.modelContainer = nil
        container = nil
        serverID = nil
        try await super.tearDown()
    }

    // MARK: - MediaItemEntityQuery (2.1, 2.2, 2.3)

    /// 2.1 — entities returned from the OfflineSync cache match the
    /// query string without any network call.
    func testEntitiesReturnedFromOfflineSync() async throws {
        let context = container.mainContext
        let dune = CachedMediaItem(
            id: "dune-1",
            serverConfigurationID: serverID,
            name: "Dune",
            year: 2021,
            mediaType: "Movie"
        )
        let bear = CachedMediaItem(
            id: "bear-1",
            serverConfigurationID: serverID,
            name: "The Bear",
            year: 2022,
            mediaType: "Series"
        )
        context.insert(dune)
        context.insert(bear)
        try context.save()

        let query = MediaItemEntityQuery()
        let results = try await query.entities(matching: "dune")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "dune-1")
        XCTAssertEqual(results.first?.title, "Dune")
    }

    /// 2.2 — empty cache returns an empty array, never throws.
    func testEmptyCacheReturnsEmpty() async throws {
        let query = MediaItemEntityQuery()
        let results = try await query.entities(matching: "anything")
        XCTAssertEqual(results, [])
    }

    /// 2.3 — `suggestedEntities()` surfaces the most recently played
    /// items (top 10) ordered by `lastPlayedDate` descending. Items
    /// with no progress fall back to `lastSyncedAt` if no progress
    /// rows exist.
    func testSuggestedEntitiesReturnsRecent() async throws {
        let context = container.mainContext
        let now = Date()

        // Three items with progress, two without.
        let withProgress = (0 ..< 3).map { idx in
            let item = CachedMediaItem(
                id: "p-\(idx)",
                serverConfigurationID: serverID,
                name: "Played \(idx)",
                mediaType: "Movie",
                playbackPositionTicks: Int64((idx + 1) * 1_000_000),
                lastPlayedDate: now.addingTimeInterval(TimeInterval(-idx * 60))
            )
            return item
        }
        let withoutProgress = (0 ..< 2).map { idx in
            CachedMediaItem(
                id: "u-\(idx)",
                serverConfigurationID: serverID,
                name: "Unplayed \(idx)",
                mediaType: "Movie"
            )
        }
        for item in withProgress + withoutProgress {
            context.insert(item)
        }
        try context.save()

        let query = MediaItemEntityQuery()
        let results = try await query.suggestedEntities()

        // First three results MUST be the played items, ordered by
        // lastPlayedDate descending.
        XCTAssertGreaterThanOrEqual(results.count, 3)
        XCTAssertEqual(results[0].id, "p-0")
        XCTAssertEqual(results[1].id, "p-1")
        XCTAssertEqual(results[2].id, "p-2")
    }

    // MARK: - RequestEntityQuery (2.4)

    /// 2.4 — entities returned from CachedRequest rows.
    func testEntitiesFromCachedRequests() async throws {
        let context = container.mainContext
        let pending = CachedRequest(
            serverConfigurationID: serverID,
            requestID: 42,
            title: "The Bear",
            mediaType: "tv",
            statusRawValue: 1, // pending
            requestedAt: Date()
        )
        let approved = CachedRequest(
            serverConfigurationID: serverID,
            requestID: 43,
            title: "Dune",
            mediaType: "movie",
            statusRawValue: 2, // approved
            requestedAt: Date().addingTimeInterval(-3600)
        )
        context.insert(pending)
        context.insert(approved)
        try context.save()

        let query = RequestEntityQuery()
        let results = try await query.entities(matching: "")

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.title == "The Bear" })
        XCTAssertTrue(results.contains { $0.title == "Dune" })
    }

    // MARK: - ServerEntityQuery (2.5, 2.6)

    /// 2.5 — every configured server appears as an entity.
    func testEntitiesFromConfiguredServers() async throws {
        let context = container.mainContext
        let personal = ServerConfiguration(
            name: "Personal",
            jellyfinURL: URL(string: "https://personal.example.com")!
        )
        let family = ServerConfiguration(
            name: "Family",
            jellyfinURL: URL(string: "https://family.example.com")!
        )
        context.insert(personal)
        context.insert(family)
        try context.save()

        let query = ServerEntityQuery()
        let results = try await query.entities(matching: "")

        XCTAssertEqual(results.count, 2)
        let names = Set(results.map(\.name))
        XCTAssertEqual(names, ["Personal", "Family"])
    }

    /// 2.6 — `defaultResult()` resolves to the active server when one
    /// is marked active, regardless of insertion order.
    func testDefaultsToActiveServer() async throws {
        let context = container.mainContext
        let personal = ServerConfiguration(
            name: "Personal",
            jellyfinURL: URL(string: "https://personal.example.com")!,
            isActive: false
        )
        let family = ServerConfiguration(
            name: "Family",
            jellyfinURL: URL(string: "https://family.example.com")!,
            isActive: true
        )
        context.insert(personal)
        context.insert(family)
        try context.save()

        let query = ServerEntityQuery()
        let result = try await query.suggestedEntities().first
        XCTAssertEqual(result?.name, "Family")

        let defaultEntity = try await query.defaultResult()
        XCTAssertEqual(defaultEntity?.name, "Family")
    }
}
