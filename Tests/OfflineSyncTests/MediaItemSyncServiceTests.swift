import JellyfinClient
@testable import OfflineSync
import SeerCore
import SwiftData
import XCTest

/// Regression coverage for `MediaItemSyncService.syncItems`.
///
/// The service used to look up existing rows by `libraryId` during a library
/// sync, so items first cached by a latest-items sync (`libraryId == nil`)
/// were inserted a second time. The next latest-items sync then trapped in
/// `Dictionary(uniqueKeysWithValues:)` on the duplicate id.
@MainActor
final class MediaItemSyncServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: MediaItemSyncService!
    private var serverConfig: ServerConfiguration!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            ServerConfiguration.self,
            CachedLibrary.self,
            CachedMediaItem.self,
            CachedUserProgress.self,
            CachedRequest.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
        service = MediaItemSyncService(modelContext: context)

        serverConfig = ServerConfiguration(
            name: "Test",
            jellyfinURL: URL(string: "https://jellyfin.example.com")!
        )
        context.insert(serverConfig)
        try context.save()
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        container = nil
        serverConfig = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func movie(_ id: String, name: String? = nil) -> MediaItem {
        MediaItem(id: id, name: name ?? "Movie \(id)", type: .movie)
    }

    private func makeLibrary(_ id: String = "lib-1") throws -> CachedLibrary {
        let library = CachedLibrary(id: id, serverConfigurationID: serverConfig.id, name: "Movies")
        context.insert(library)
        try context.save()
        return library
    }

    private func cachedItems(id: String? = nil) throws -> [CachedMediaItem] {
        let descriptor: FetchDescriptor<CachedMediaItem> = if let id {
            FetchDescriptor(predicate: #Predicate { $0.id == id })
        } else {
            FetchDescriptor()
        }
        return try context.fetch(descriptor)
    }

    // MARK: - Tests

    func testLibrarySyncAfterLatestSync_updatesRowInsteadOfDuplicating() async throws {
        // Latest-items sync caches the movie without a library
        try await service.syncItems([movie("a")], serverConfig: serverConfig, library: nil)
        XCTAssertEqual(try cachedItems(id: "a").count, 1)
        XCTAssertNil(try cachedItems(id: "a").first?.libraryId)

        // Library sync of the same movie must reuse that row
        let library = try makeLibrary()
        try await service.syncItems(
            [movie("a", name: "Renamed"), movie("b")],
            serverConfig: serverConfig,
            library: library
        )

        let rowsForA = try cachedItems(id: "a")
        XCTAssertEqual(rowsForA.count, 1, "Library sync must not insert a second row for the same id")
        XCTAssertEqual(rowsForA.first?.libraryId, library.id)
        XCTAssertEqual(rowsForA.first?.name, "Renamed")
        XCTAssertEqual(try cachedItems().count, 2)

        // A subsequent latest-items sync must not trap on duplicate keys
        try await service.syncItems([movie("a")], serverConfig: serverConfig, library: nil)
        XCTAssertEqual(try cachedItems().count, 2)
    }

    func testSync_collapsesPreexistingDuplicateRows() async throws {
        // Simulate what CloudKit merges can produce: two rows with one id
        for _ in 0 ..< 2 {
            context.insert(
                CachedMediaItem(
                    id: "dup",
                    serverConfigurationID: serverConfig.id,
                    name: "Dup",
                    mediaType: "Movie"
                )
            )
        }
        try context.save()
        XCTAssertEqual(try cachedItems(id: "dup").count, 2)

        try await service.syncItems([movie("dup")], serverConfig: serverConfig, library: nil)

        XCTAssertEqual(try cachedItems(id: "dup").count, 1)
    }

    func testLibrarySync_removesItemsNoLongerOnServer() async throws {
        let library = try makeLibrary()
        try await service.syncItems([movie("a"), movie("b")], serverConfig: serverConfig, library: library)
        XCTAssertEqual(try cachedItems().count, 2)

        try await service.syncItems([movie("a")], serverConfig: serverConfig, library: library)

        XCTAssertEqual(try cachedItems(id: "b").count, 0, "Item gone from the library must be deleted")
        XCTAssertEqual(try cachedItems(id: "a").count, 1)
    }

    func testLatestSync_doesNotDeleteUnrelatedItems() async throws {
        let library = try makeLibrary()
        try await service.syncItems([movie("a"), movie("b")], serverConfig: serverConfig, library: library)

        // Latest sync returns only "a"; "b" must survive because no library scope applies
        try await service.syncItems([movie("a")], serverConfig: serverConfig, library: nil)

        XCTAssertEqual(try cachedItems().count, 2)
    }

    func testSync_isScopedToServerConfiguration() async throws {
        let otherServer = try ServerConfiguration(
            name: "Other",
            jellyfinURL: XCTUnwrap(URL(string: "https://other.example.com"))
        )
        context.insert(otherServer)
        try context.save()

        try await service.syncItems([movie("shared")], serverConfig: serverConfig, library: nil)
        try await service.syncItems([movie("shared")], serverConfig: otherServer, library: nil)

        let rows = try cachedItems(id: "shared")
        XCTAssertEqual(rows.count, 2, "Same item id on two servers must be two rows")
        XCTAssertEqual(Set(rows.map(\.serverConfigurationID)), [serverConfig.id, otherServer.id])
    }
}
