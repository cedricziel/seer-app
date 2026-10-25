@testable import DownloadClient
import SwiftData
import XCTest

final class DownloadPlaybackProgressTests: XCTestCase {
    func testSavedProgressSurvivesStoreRecreationAndIsPendingSync() async throws {
        let container = try makeContainer()
        let store = DownloadStore(modelContainer: container)
        let download = makeDownload(serverID: "server-a")
        try await store.insert(download)

        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 600_000_000, isWatched: false)

        let restored = DownloadStore(modelContainer: container)
        let pending = try await restored.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.positionTicks, 600_000_000)
        XCTAssertEqual(pending.first?.isWatched, false)
    }

    func testSuccessfulSyncAcknowledgesOnlyRequestedServer() async throws {
        let store = try DownloadStore(modelContainer: makeContainer())
        let first = makeDownload(serverID: "server-a")
        let second = makeDownload(serverID: "server-b")
        try await store.insert(first)
        try await store.insert(second)
        try await store.updatePlaybackPosition(downloadID: first.id, positionTicks: 10, isWatched: true)
        try await store.updatePlaybackPosition(downloadID: second.id, positionTicks: 20, isWatched: false)
        let sink = ProgressSink()

        await store.syncPlaybackProgress(serverID: "server-a") { await sink.record($0) }

        let sent = await sink.values
        let firstPending = try await store.pendingPlaybackProgress(serverID: "server-a")
        let secondPending = try await store.pendingPlaybackProgress(serverID: "server-b")
        XCTAssertEqual(sent.map(\.itemID), [first.itemID])
        XCTAssertEqual(sent.first?.isWatched, true)
        XCTAssertTrue(firstPending.isEmpty)
        XCTAssertEqual(secondPending.count, 1)
    }

    func testFailedSyncKeepsProgressForRetry() async throws {
        let store = try DownloadStore(modelContainer: makeContainer())
        let download = makeDownload(serverID: "server-a")
        try await store.insert(download)
        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 30, isWatched: false)

        await store.syncPlaybackProgress(serverID: "server-a") { _ in throw URLError(.notConnectedToInternet) }

        let pending = try await store.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertEqual(pending.first?.positionTicks, 30)
        await store.syncPlaybackProgress(serverID: "server-a") { _ in }
        let afterRetry = try await store.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertTrue(afterRetry.isEmpty)
    }

    func testSaveDuringSyncRemainsPending() async throws {
        let store = try DownloadStore(modelContainer: makeContainer())
        let download = makeDownload(serverID: "server-a")
        try await store.insert(download)
        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 30, isWatched: false)

        await store.syncPlaybackProgress(serverID: "server-a") { progress in
            try await store.updatePlaybackPosition(downloadID: progress.downloadID, positionTicks: 60, isWatched: true)
        }

        let pending = try await store.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertEqual(pending.first?.positionTicks, 60)
        XCTAssertEqual(pending.first?.isWatched, true)
    }

    func testDeletingMediaKeepsProgressUntilReconnectAcknowledgesIt() async throws {
        let container = try makeContainer()
        let store = DownloadStore(modelContainer: container)
        let download = makeDownload(serverID: "server-a")
        try await store.insert(download)
        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 90, isWatched: true)

        try await store.delete(downloadID: download.id)

        let relaunched = DownloadStore(modelContainer: container)
        let pending = try await relaunched.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertEqual(pending.first?.positionTicks, 90)
        XCTAssertEqual(pending.first?.isWatched, true)
        let sink = ProgressSink()
        await relaunched.syncPlaybackProgress(serverID: "server-a") { await sink.record($0) }
        let sent = await sink.values
        let remaining = try await relaunched.pendingPlaybackProgress(serverID: "server-a")
        XCTAssertEqual(sent.count, 1)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testOverlappingSyncDoesNotSendTheSameProgressTwice() async throws {
        let store = try DownloadStore(modelContainer: makeContainer())
        let download = makeDownload(serverID: "server-a")
        try await store.insert(download)
        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 30, isWatched: false)
        let sink = ProgressSink()

        await store.syncPlaybackProgress(serverID: "server-a") { progress in
            await sink.record(progress)
            await store.syncPlaybackProgress(serverID: "server-a") { await sink.record($0) }
        }

        let sent = await sink.values
        XCTAssertEqual(sent.count, 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Download.self, AutoDownloadRule.self, PendingDownloadProgress.self])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    private func makeDownload(serverID: String) -> Download {
        let download = Download(
            serverID: serverID,
            itemID: "same-item",
            mediaSourceID: "source",
            name: "Movie",
            mediaType: "Movie"
        )
        download.state = .completed
        return download
    }
}

private actor ProgressSink {
    var values: [DownloadPlaybackProgress] = []

    func record(_ value: DownloadPlaybackProgress) {
        values.append(value)
    }
}
