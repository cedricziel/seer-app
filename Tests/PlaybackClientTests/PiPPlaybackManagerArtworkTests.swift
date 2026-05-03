#if canImport(UIKit)
    import MediaPlayer
    @testable import PlaybackClient
    import UIKit
    import XCTest

    /// Regression tests for the SIGTRAP that crashed TestFlight build 138
    /// when `MPNowPlayingInfoCenter` invoked the artwork `requestHandler`
    /// from its own internal serial queue. Pre-fix, the handler closure
    /// inherited `@MainActor` isolation from its enclosing context and
    /// the Swift 6 strict-concurrency runtime trapped via
    /// `_dispatch_assert_queue_fail` when the system pulled the bitmap
    /// off-main.
    ///
    /// The fix: build the artwork from a `nonisolated` static helper so
    /// the closure inherits no actor isolation. These tests verify that
    /// invariant by calling the handler from a non-main dispatch queue.
    final class PiPPlaybackManagerArtworkTests: XCTestCase {
        private let red = UIImage(
            systemName: "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)
        ) ?? UIImage()

        /// The crash signature: artwork handler called off-main must
        /// produce the bitmap without trapping. If the closure ever
        /// regresses to `@MainActor`, this test traps with the same
        /// `_dispatch_assert_queue_fail` we saw in the wild crash log.
        func testArtworkHandlerCanBeInvokedOffMain() async {
            let artwork = PiPPlaybackManager.makeArtwork(from: red)

            // Verify on a non-main background queue. We use a
            // non-cooperative DispatchQueue (not Swift's task pool) so the
            // executor check has something concrete to assert against.
            let result: UIImage? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = artwork.image(at: artwork.bounds.size)
                    continuation.resume(returning: image)
                }
            }

            XCTAssertNotNil(
                result,
                "Artwork handler must return the captured image when invoked off-main"
            )
        }

        /// Repeat invocations off-main are also safe — `MPNowPlayingInfo-
        /// Center` hits the handler many times during a session.
        func testArtworkHandlerSurvivesRepeatedOffMainInvocation() async {
            let artwork = PiPPlaybackManager.makeArtwork(from: red)

            for _ in 0 ..< 10 {
                let result: UIImage? = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(returning: artwork.image(at: artwork.bounds.size))
                    }
                }
                XCTAssertNotNil(result)
            }
        }

        /// Sanity check from main — the handler also works from the main
        /// queue (lock-screen pulls sometimes happen there too).
        @MainActor
        func testArtworkHandlerWorksOnMain() {
            let artwork = PiPPlaybackManager.makeArtwork(from: red)
            let result = artwork.image(at: artwork.bounds.size)
            XCTAssertNotNil(result)
        }
    }
#endif
