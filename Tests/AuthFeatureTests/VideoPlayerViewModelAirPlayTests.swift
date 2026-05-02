#if os(iOS)
    import AVFoundation
    import JellyfinClient
    @testable import SeerApp
    import SeerCore
    import SwiftData
    import XCTest

    /// Verifies that constructing a `VideoPlayerViewModel` enables external
    /// playback on the underlying `AVPlayer`, so AirPlay routing works without
    /// relying on undocumented `AVPlayer` defaults.
    @MainActor
    final class VideoPlayerViewModelAirPlayTests: XCTestCase {
        private var appState: AppState!
        private var modelContainer: ModelContainer!

        override func setUp() async throws {
            try await super.setUp()
            let schema = Schema([ServerConfiguration.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            appState = AppState()
            appState.setModelContext(ModelContext(modelContainer))
        }

        override func tearDown() async throws {
            appState = nil
            modelContainer = nil
            try await super.tearDown()
        }

        func testInitWithExistingPlayer_enablesExternalPlayback() throws {
            let player = AVPlayer()
            // Override defaults so the assertions verify our explicit assignment
            // rather than the framework defaults.
            player.allowsExternalPlayback = false
            XCTAssertFalse(player.usesExternalPlaybackWhileExternalScreenIsActive)

            _ = VideoPlayerViewModel(
                item: makeMediaItem(),
                appState: try XCTUnwrap(appState),
                existingPlayer: player
            )

            XCTAssertTrue(
                player.allowsExternalPlayback,
                "VideoPlayerViewModel must enable AirPlay/external playback on the underlying AVPlayer"
            )
            XCTAssertTrue(
                player.usesExternalPlaybackWhileExternalScreenIsActive,
                "VideoPlayerViewModel must allow external playback while an external screen is active"
            )
        }

        // MARK: - Helpers

        private func makeMediaItem() -> MediaItem {
            MediaItem(
                id: "test-\(UUID().uuidString)",
                name: "Test Movie",
                type: .movie
            )
        }
    }
#endif
