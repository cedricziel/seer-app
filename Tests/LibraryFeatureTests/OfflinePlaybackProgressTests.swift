import AVFoundation
import Combine
import DownloadClient
import JellyfinClient
@testable import SeerApp
import SeerCore
import SwiftData
import XCTest

@MainActor
final class OfflinePlaybackProgressTests: XCTestCase {
    private var directory: URL!
    private var store: DownloadStore!
    private var backend: LocalPlaybackBackend!
    private var model: VideoPlayerViewModel!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([Download.self, AutoDownloadRule.self, PendingDownloadProgress.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        store = DownloadStore(modelContainer: container)
        let url = directory.appendingPathComponent("media.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480_000))
        buffer.floatChannelData?.pointee.initialize(repeating: 0, count: 480_000)
        buffer.frameLength = 480_000
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        backend = LocalPlaybackBackend(store: store, url: url)
    }

    override func tearDown() async throws {
        model?.stop()
        await model?.localProgressSaveTask?.value
        model = nil
        backend = nil
        store = nil
        try FileManager.default.removeItem(at: directory)
    }

    func testResumeUsesSavedLocalPositionInsteadOfStaleLibraryPosition() async throws {
        let download = try await insertDownload()
        try await store.updatePlaybackPosition(downloadID: download.id, positionTicks: 2_500_000, isWatched: false)
        model = makeModel()

        await model.loadMedia(startPositionTicks: 9_000_000)

        XCTAssertEqual(model.currentTime, 0.25)
        XCTAssertTrue(model.isReady)
        XCTAssertNil(model.errorMessage)
    }

    func testPausePersistsLocalSeekPosition() async throws {
        let download = try await insertDownload()
        model = makeModel()
        await model.loadMedia()
        await model.seek(to: 0.5)

        model.pause()
        await model.localProgressSaveTask?.value

        let saved = try await store.fetchDownload(id: download.id)
        XCTAssertEqual(saved?.playbackPositionTicks, 5_000_000)
        let pending = try await store.pendingPlaybackProgress(serverID: "stored-server")
        XCTAssertEqual(pending.first?.positionTicks, 5_000_000)
    }

    func testStopPersistsProgressWithOriginalServerIdentity() async throws {
        let download = try await insertDownload()
        model = makeModel()
        await model.loadMedia(startPositionTicks: 4_000_000)

        model.stop()
        await model.localProgressSaveTask?.value

        let pending = try await store.pendingPlaybackProgress(serverID: "stored-server")
        XCTAssertEqual(pending.first?.downloadID, download.id)
        XCTAssertEqual(pending.first?.positionTicks, 4_000_000)
        XCTAssertEqual(backend.requestedServers, ["stored-server"])
    }

    func testNativePlayerPausePersistsProgress() async throws {
        _ = try await insertDownload()
        model = makeModel()
        await model.loadMedia()
        let player = try XCTUnwrap(model.player)
        player.isMuted = true
        let started = expectation(description: "Player started")
        let subscription = player.publisher(for: \.timeControlStatus)
            .filter { $0 == .playing }
            .first()
            .sink { _ in started.fulfill() }
        defer { subscription.cancel() }
        model.play()
        await fulfillment(of: [started], timeout: 3)
        let saved = expectation(description: "Native pause saved")
        backend.onSave = { saved.fulfill() }

        player.pause()
        await fulfillment(of: [saved], timeout: 2)

        let pending = try await store.pendingPlaybackProgress(serverID: "stored-server")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.isWatched, false)
    }

    func testNaturalEndPersistsWatchedStatus() async throws {
        let download = try await insertDownload()
        model = makeModel()
        await model.loadMedia()
        let saved = expectation(description: "Playback end saved")
        backend.onSave = { saved.fulfill() }

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: model.player?.currentItem)
        await fulfillment(of: [saved], timeout: 2)

        let stored = try await store.fetchDownload(id: download.id)
        XCTAssertEqual(stored?.isWatched, true)
        XCTAssertEqual(stored?.playbackPositionTicks, 600_000_000)
    }

    func testMissingExplicitDownloadDoesNotTryActiveServerStreaming() async {
        model = makeModel()

        await model.loadMedia()

        XCTAssertNil(model.player)
        XCTAssertFalse(model.isReady)
        XCTAssertEqual(model.errorMessage, "The downloaded file is unavailable. Download this item again.")
    }

    private func insertDownload() async throws -> Download {
        let download = Download(
            serverID: "stored-server", itemID: "movie", mediaSourceID: "source", name: "Movie", mediaType: "Movie"
        )
        download.state = .completed
        download.relativePath = "unused.wav"
        try await store.insert(download)
        return download
    }

    private func makeModel() -> VideoPlayerViewModel {
        VideoPlayerViewModel(
            item: MediaItem(id: "movie", name: "Movie", type: .movie),
            appState: AppState(),
            downloadManager: backend,
            downloadServerID: "stored-server"
        )
    }
}

@MainActor
private final class LocalPlaybackBackend: DownloadPlaybackManaging {
    let store: DownloadStore
    let url: URL
    var requestedServers: [String] = []
    var onSave: (() -> Void)?

    init(store: DownloadStore, url: URL) {
        self.store = store
        self.url = url
    }

    func download(forItemID itemID: String, serverID: String) async -> Download? {
        requestedServers.append(serverID)
        return try? await store.fetchDownload(itemID: itemID, serverID: serverID)
    }

    func localFileURL(forItemID _: String, serverID _: String) async -> URL? {
        url
    }

    func updatePlaybackPosition(downloadID: UUID, positionTicks: Int64, isWatched: Bool) async throws {
        try await store.updatePlaybackPosition(
            downloadID: downloadID,
            positionTicks: positionTicks,
            isWatched: isWatched
        )
        onSave?()
    }
}
