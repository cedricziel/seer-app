@testable import DownloadClient
import Foundation
import JellyfinClient
import SwiftData
import XCTest

@MainActor
final class DownloadRegressionTests: XCTestCase {
    private var manager: DownloadManager!
    private var sessionManager: BackgroundSessionManager!
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let schema = Schema([Download.self, AutoDownloadRule.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DownloadRequestTrap.self]
        sessionManager = BackgroundSessionManager(configuration: configuration)
        manager = try DownloadManager(
            modelContainer: container, storage: DownloadStorage(downloadsDirectory: directory),
            sessionManager: sessionManager, queue: DownloadQueue()
        )
        manager.configure(
            serverURL: URL(string: "https://download.invalid")!, accessToken: "test-token",
            userID: "test-user", deviceID: "test-device", serverID: "test-server"
        )
        await manager.pauseQueue()
    }

    override func tearDown() async throws {
        sessionManager.session.invalidateAndCancel()
        manager = nil
        sessionManager = nil
        try FileManager.default.removeItem(at: directory)
    }

    func testCompletedUnknownLengthUsesActualFileBytes() async throws {
        let download = makeDownload()
        try await manager.store.insert(download)
        try await manager.store.updateProgress(downloadID: download.id, progress: 0, bytesDownloaded: 7, totalBytes: -1)
        let file = directory.appendingPathComponent("transfer.tmp")
        try Data(repeating: 1, count: 4096).write(to: file)

        await manager.finalizeDownload(downloadID: download.id, tempFileURL: file)

        let saved = try await manager.store.fetchDownload(id: download.id)
        XCTAssertEqual(saved?.state, .completed)
        XCTAssertEqual(saved?.totalBytes, 4096)
        XCTAssertEqual(saved?.bytesDownloaded, 4096)
        let total = try await manager.store.totalDownloadedSize()
        XCTAssertEqual(total, 4096)
    }

    func testUnknownLengthProgressNeverPersistsNegativeSize() async throws {
        let download = makeDownload()
        try await manager.store.insert(download)
        try await manager.store.updateProgress(downloadID: download.id, progress: 0, bytesDownloaded: 7, totalBytes: -1)
        let saved = try await manager.store.fetchDownload(id: download.id)
        XCTAssertEqual(saved?.totalBytes, 0)
    }

    private func makeDownload() -> Download {
        Download(
            serverID: "test-server",
            itemID: "episode",
            mediaSourceID: "source",
            name: "Episode",
            mediaType: "Episode"
        )
    }
}

private class DownloadRequestTrap: URLProtocol, @unchecked Sendable {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        XCTFail("Unexpected transfer request")
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}
