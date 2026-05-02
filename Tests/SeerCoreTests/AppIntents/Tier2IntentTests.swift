@testable import SeerCore
import AppIntents
import SwiftData
import XCTest

private extension URL {
    static func test(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Bad test URL: \(string)")
        }
        return url
    }
}

/// Tier 2 intent coverage: MarkAsWatched, DownloadForOffline,
/// CheckRequestStatus.
@MainActor
final class Tier2IntentTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
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

        AppIntentsContext.modelContainer = container
        AppIntentsContext.appState = appState

        serverID = UUID()

        MarkAsWatchedIntent.updater = { _ in throw IntentError.serverNotReachable }
        DownloadForOfflineIntent.enqueuer = { _ in throw IntentError.serverNotReachable }
    }

    override func tearDown() async throws {
        AppIntentsContext.modelContainer = nil
        AppIntentsContext.appState = nil
        container = nil
        appState = nil
        serverID = nil
        try await super.tearDown()
    }

    private func insertActiveServer() {
        let server = ServerConfiguration(
            id: serverID,
            name: "Test",
            jellyfinURL: URL.test("https://jellyfin.example.com"),
            isActive: true
        )
        container.mainContext.insert(server)
        try? container.mainContext.save()
        appState.isAuthenticated = true
    }

    // MARK: - 4.10 — MarkAsWatchedIntent

    /// 4.10 — Updater receives the resolved id + watched flag.
    func testCallsJellyfinSetPlayed() async throws {
        insertActiveServer()
        let captured = AtomicValue<MarkAsWatchedSubmission>()
        MarkAsWatchedIntent.updater = { submission in
            captured.set(submission)
        }

        let entity = MediaItemEntity(id: "the-bear", title: "The Bear")
        let intent = MarkAsWatchedIntent(item: entity, watched: true)
        _ = try await intent.perform()

        XCTAssertEqual(captured.value?.itemID, "the-bear")
        XCTAssertEqual(captured.value?.watched, true)
    }

    // MARK: - 4.11 — DownloadForOfflineIntent

    /// 4.11 — Enqueuer receives the entity id.
    func testEnqueuesDownloadJob() async throws {
        insertActiveServer()
        let captured = AtomicValue<DownloadEnqueuePayload>()
        DownloadForOfflineIntent.enqueuer = { payload in
            captured.set(payload)
        }

        let entity = MediaItemEntity(id: "dune", title: "Dune")
        let intent = DownloadForOfflineIntent(item: entity)
        _ = try await intent.perform()

        XCTAssertEqual(captured.value?.itemID, "dune")
        XCTAssertEqual(captured.value?.title, "Dune")
    }

    // MARK: - 4.12 / 4.12a — CheckRequestStatusIntent

    /// 4.12 — Returns cached requests ordered descending.
    func testReturnsListOfPendingAndReady() async throws {
        insertActiveServer()
        let context = container.mainContext
        context.insert(CachedRequest(
            serverConfigurationID: serverID,
            requestID: 1,
            title: "Pending Movie",
            mediaType: "movie",
            statusRawValue: 1,
            requestedAt: Date()
        ))
        context.insert(CachedRequest(
            serverConfigurationID: serverID,
            requestID: 2,
            title: "Available Movie",
            mediaType: "movie",
            statusRawValue: 4,
            requestedAt: Date().addingTimeInterval(-3600)
        ))
        try context.save()

        let result = try await CheckRequestStatusIntent().perform()
        XCTAssertEqual(result.value?.count, 2)
        XCTAssertEqual(result.value?.first?.title, "Pending Movie")
    }

    /// 4.12a — Empty cache returns empty array + the helper snippet.
    func testReturnsEmptySnippetOnFreshInstall() async throws {
        insertActiveServer()
        let result = try await CheckRequestStatusIntent().perform()
        XCTAssertEqual(result.value?.count, 0)
    }
}
