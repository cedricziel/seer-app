import OfflineSync
import SeerCore
import SwiftData
import XCTest

@MainActor
final class UserProgressSyncServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: UserProgressSyncService!

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
        context = container.mainContext
        service = UserProgressSyncService(modelContext: context)
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    func testQueuePreservesSeparateUpdatesForSameItemOnDifferentServers() throws {
        let serverA = UUID()
        let serverB = UUID()
        let existing = CachedUserProgress(
            mediaItemId: "shared",
            serverConfigurationID: serverA,
            playbackPositionTicks: 100
        )
        context.insert(existing)
        try context.save()

        service.queueProgressUpdate(
            mediaItemId: "shared",
            serverConfigurationID: serverB,
            playbackPositionTicks: 200,
            isFavorite: true,
            isPlayed: true
        )

        let rows = try context.fetch(FetchDescriptor<CachedUserProgress>())
        let updateB = try XCTUnwrap(rows.first { $0.serverConfigurationID == serverB })
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(existing.playbackPositionTicks, 100)
        XCTAssertFalse(existing.isFavorite)
        XCTAssertFalse(existing.isPlayed)
        XCTAssertEqual(updateB.playbackPositionTicks, 200)
        XCTAssertTrue(updateB.isFavorite)
        XCTAssertTrue(updateB.isPlayed)
    }

    func testQueueCoalescesPendingUpdatesForSameItemAndServer() throws {
        let serverID = UUID()
        let existing = CachedUserProgress(
            mediaItemId: "shared",
            serverConfigurationID: serverID,
            playbackPositionTicks: 100
        )
        context.insert(existing)
        try context.save()

        service.queueProgressUpdate(
            mediaItemId: "shared",
            serverConfigurationID: serverID,
            playbackPositionTicks: 200,
            isFavorite: true,
            isPlayed: true
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CachedUserProgress>()), 1)
        XCTAssertEqual(existing.playbackPositionTicks, 200)
        XCTAssertTrue(existing.isFavorite)
        XCTAssertTrue(existing.isPlayed)
    }

    func testSaveProgressDoesNotChangeAnotherServersCachedItem() throws {
        let serverA = UUID()
        let serverB = UUID()
        let itemA = CachedMediaItem(
            id: "shared",
            serverConfigurationID: serverA,
            name: "Movie A",
            mediaType: "Movie",
            playbackPositionTicks: 100
        )
        context.insert(itemA)
        try context.save()
        let offlineService = OfflineSyncService(modelContext: context)

        offlineService.saveProgress(
            mediaItemId: "shared",
            serverConfigurationID: serverB,
            playbackPositionTicks: 300,
            isFavorite: true,
            isPlayed: true
        )

        XCTAssertEqual(itemA.playbackPositionTicks, 100)
        XCTAssertFalse(itemA.isFavorite)
        XCTAssertFalse(itemA.isPlayed)
    }

    func testSaveProgressUpdatesTargetServersCachedItem() throws {
        let serverID = UUID()
        let item = CachedMediaItem(
            id: "movie",
            serverConfigurationID: serverID,
            name: "Movie",
            mediaType: "Movie",
            playbackPositionTicks: 100
        )
        context.insert(item)
        try context.save()
        let offlineService = OfflineSyncService(modelContext: context)

        offlineService.saveProgress(
            mediaItemId: "movie",
            serverConfigurationID: serverID,
            playbackPositionTicks: 200,
            isFavorite: true,
            isPlayed: true
        )

        XCTAssertEqual(item.playbackPositionTicks, 200)
        XCTAssertTrue(item.isFavorite)
        XCTAssertTrue(item.isPlayed)
    }
}
