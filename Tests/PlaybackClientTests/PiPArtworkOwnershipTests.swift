#if canImport(UIKit)
    import JellyfinClient
    import MediaPlayer
    @testable import PlaybackClient
    import UIKit
    import XCTest

    @MainActor
    final class PiPArtworkOwnershipTests: XCTestCase {
        override func tearDown() async throws {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try await super.tearDown()
        }

        func testArtworkFinishingAfterCloseCannotRecreateNowPlaying() async throws {
            let loader = PendingArtwork()
            let manager = PiPPlaybackManager(artworkLoader: { try await loader.load($0) })
            update(manager, id: "old", url: "https://example.invalid/old")
            let task = try XCTUnwrap(manager.artworkTask)
            await loader.waitForRequests(1)

            manager.clearPlayer()
            try await loader.complete(0, data: imageData())
            await task.value

            XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        }

        func testOlderArtworkCannotReplaceNewItemArtworkAtSameURL() async throws {
            let loader = PendingArtwork()
            let manager = PiPPlaybackManager(artworkLoader: { try await loader.load($0) })
            update(manager, id: "old", url: "https://example.invalid/shared")
            let oldTask = try XCTUnwrap(manager.artworkTask)
            await loader.waitForRequests(1)
            update(manager, id: "new", url: "https://example.invalid/shared")
            let newTask = try XCTUnwrap(manager.artworkTask)
            await loader.waitForRequests(2)
            try await loader.complete(1, data: imageData())
            await newTask.value
            let artwork = MPNowPlayingInfoCenter.default()
                .nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork

            try await loader.complete(0, data: imageData())
            await oldTask.value

            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "new")
            XCTAssertIdentical(info?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork, artwork)
        }

        func testOldArtworkCannotAttachToMetadataWithoutArtwork() async throws {
            let loader = PendingArtwork()
            let manager = PiPPlaybackManager(artworkLoader: { try await loader.load($0) })
            update(manager, id: "old", url: "https://example.invalid/old")
            let task = try XCTUnwrap(manager.artworkTask)
            await loader.waitForRequests(1)
            manager.updateNowPlayingInfo(
                for: MediaItem(id: "new", name: "new", type: .movie),
                duration: nil, elapsed: 0, rate: 0, imageURL: nil
            )

            try await loader.complete(0, data: imageData())
            await task.value

            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "new")
            XCTAssertNil(info?[MPMediaItemPropertyArtwork])
        }

        func testCurrentArtworkKeepsLatestPlaybackTime() async throws {
            let loader = PendingArtwork()
            let manager = PiPPlaybackManager(artworkLoader: { try await loader.load($0) })
            update(manager, id: "current", url: "https://example.invalid/current")
            let task = try XCTUnwrap(manager.artworkTask)
            await loader.waitForRequests(1)
            manager.updateNowPlayingPlaybackTime(elapsed: 42, rate: 0)

            try await loader.complete(0, data: imageData())
            await task.value

            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            XCTAssertNotNil(info?[MPMediaItemPropertyArtwork])
            XCTAssertEqual(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 42)
            XCTAssertEqual(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Float, 0)
        }

        private func update(_ manager: PiPPlaybackManager, id: String, url: String) {
            manager.updateNowPlayingInfo(
                for: MediaItem(id: id, name: id, type: .movie),
                duration: nil, elapsed: 0, rate: 1, imageURL: URL(string: url)
            )
        }

        private func imageData() throws -> Data {
            try XCTUnwrap(UIImage(systemName: "play.fill")?.pngData())
        }
    }

    private actor PendingArtwork {
        private var requests: [CheckedContinuation<Data, any Error>] = []
        private var waiter: CheckedContinuation<Void, Never>?
        private var expectedCount = 0

        func load(_: URL) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                requests.append(continuation)
                if requests.count >= expectedCount {
                    waiter?.resume()
                    waiter = nil
                }
            }
        }

        func waitForRequests(_ count: Int) async {
            guard requests.count < count else { return }
            expectedCount = count
            await withCheckedContinuation { waiter = $0 }
        }

        func complete(_ index: Int, data: Data) {
            requests[index].resume(returning: data)
        }
    }
#endif
