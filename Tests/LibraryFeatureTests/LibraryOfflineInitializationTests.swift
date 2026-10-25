import JellyfinClient
import OfflineSync
import os
@testable import SeerApp
import SeerCore
import SwiftData
import XCTest

@MainActor
final class LibraryOfflineInitializationTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var monitor: NetworkMonitor!
    private var server: ServerConfiguration!

    override func setUp() async throws {
        OfflineRequestTrap.requests.withLock { $0 = 0 }
        URLProtocol.registerClass(OfflineRequestTrap.self)
        let schema = Schema([
            ServerConfiguration.self, CachedLibrary.self, CachedMediaItem.self,
            CachedUserProgress.self, CachedRequest.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        server = ServerConfiguration(
            name: "Offline test", jellyfinURL: URL(string: "https://offline.invalid")!,
            jellyfinUserID: "test-user", isActive: true
        )
        container.mainContext.insert(server)
        let library = CachedLibrary(id: "movies", serverConfigurationID: server.id, name: "Cached movies")
        container.mainContext.insert(library)
        container.mainContext.insert(CachedMediaItem(
            id: "movie", serverConfigurationID: server.id, name: "Cached movie", mediaType: "Movie",
            playbackPositionTicks: 100, libraryId: library.id, library: library
        ))
        try container.mainContext.save()
        XCTAssertTrue(KeychainManager.shared.saveCredential("test-token", for: server.id, key: .jellyfinAccessToken))
        XCTAssertTrue(KeychainManager.shared.saveCredential("test-device", for: server.id, key: .jellyfinDeviceID))
        appState = AppState()
        appState.setModelContext(container.mainContext)
        monitor = NetworkMonitor(isConnected: false)
    }

    override func tearDown() async throws {
        XCTAssertEqual(OfflineRequestTrap.requests.withLock { $0 }, 0, "Offline browsing must not request the server")
        URLProtocol.unregisterClass(OfflineRequestTrap.self)
        KeychainManager.shared.deleteServerCredentials(for: server.id)
        monitor = nil
        appState = nil
        server = nil
        container = nil
    }

    func testHomeEntryLoadsCachedLibrariesAndContinueWatching() async {
        let model = LibraryViewModel(appState: appState)

        await model.loadHome(modelContext: container.mainContext, networkMonitor: monitor)

        XCTAssertEqual(model.libraries.map(\.name), ["Cached movies"])
        XCTAssertEqual(model.continueWatching.map(\.id), ["movie"])
        XCTAssertTrue(model.isShowingCachedData)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testIndependentGridEntryLoadsCachedLibraryItems() async throws {
        let model = LibraryViewModel(appState: appState)

        try await model.enterDestination(
            .library(JSONDecoder().decode(
                Library.self, from: Data(#"{"Id":"movies","Name":"Cached movies"}"#.utf8)
            )),
            modelContext: container.mainContext, networkMonitor: monitor
        )

        XCTAssertEqual(model.mediaItems.map(\.id), ["movie"])
        XCTAssertTrue(model.isShowingCachedData)
        XCTAssertNil(model.errorMessage)
    }

    func testCachedSeriesOpensSeasonsAndEpisodesOffline() async throws {
        let context = container.mainContext
        let series = CachedMediaItem(
            id: "series", serverConfigurationID: server.id, name: "Cached show", mediaType: "Series"
        )
        let season = CachedMediaItem(
            id: "season", serverConfigurationID: server.id, name: "Season 1", mediaType: "Season",
            indexNumber: 1, parentSeries: series
        )
        let episode = CachedMediaItem(
            id: "episode", serverConfigurationID: server.id, name: "Cached episode", mediaType: "Episode",
            indexNumber: 1, parentIndexNumber: 1, parentSeason: season
        )
        context.insert(series)
        context.insert(season)
        context.insert(episode)
        try context.save()
        let model = SeriesDetailViewModel(
            series: MediaItem(id: "series", name: "Cached show", type: .series), appState: appState
        )
        model.setupOfflineSync(modelContext: context, networkMonitor: monitor)

        await model.loadSeasons()

        XCTAssertEqual(model.seasons.map(\.id), ["season"])
        XCTAssertEqual(model.selectedSeasonID, "season")
        XCTAssertEqual(model.episodesBySeason["season"]?.map(\.id), ["episode"])
        XCTAssertTrue(model.isShowingCachedData)
    }

    func testMovieDetailsUseCacheWhileOffline() async {
        let model = LibraryViewModel(appState: appState)
        await model.loadHome(modelContext: container.mainContext, networkMonitor: monitor)

        let item = await model.getItemDetails(id: "movie")

        XCTAssertEqual(item?.name, "Cached movie")
    }

    func testIndependentRecentlyAddedEntryLoadsCachedItems() async {
        let model = LibraryViewModel(appState: appState)

        await model.enterDestination(
            .recentlyAdded, modelContext: container.mainContext, networkMonitor: monitor
        )

        XCTAssertEqual(model.mediaItems.map(\.id), ["movie"])
        XCTAssertTrue(model.isShowingCachedData)
        XCTAssertTrue(model.isRecentlyAddedFeed)
    }
}

private class OfflineRequestTrap: URLProtocol, @unchecked Sendable {
    static let requests = OSAllocatedUnfairLock(initialState: 0)

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "offline.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.withLock { $0 += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
