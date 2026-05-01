import AVKit
@testable import JellyfinClient
@testable import PlaybackClient
import XCTest

/// Mock delegate for testing
@MainActor
class MockAVPlayerViewControllerDelegate: NSObject, AVPlayerViewControllerDelegate {}

@MainActor
final class PiPPlaybackManagerTests: XCTestCase {
    var mockDelegate: MockAVPlayerViewControllerDelegate!
    var sut: PiPPlaybackManager!

    override func setUp() async throws {
        try await super.setUp()
        mockDelegate = MockAVPlayerViewControllerDelegate()
        sut = PiPPlaybackManager.shared
        // Reset state before each test
        sut.clearPlayer()
    }

    override func tearDown() async throws {
        sut.clearPlayer()
        sut = nil
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(sut.pipPlayer)
        XCTAssertNil(sut.pipItem)
        XCTAssertNil(sut.pipController)
        XCTAssertFalse(sut.isPiPActive)
        XCTAssertFalse(sut.shouldRestorePlayer)
        XCTAssertFalse(sut.isRestoring)
    }

    // MARK: - PiP Start Tests

    func testPipDidStart_setsStateCorrectly() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()

        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        XCTAssertIdentical(sut.pipPlayer, player)
        XCTAssertEqual(sut.pipItem?.id, item.id)
        XCTAssertIdentical(sut.pipController, controller)
        XCTAssertTrue(sut.isPiPActive)
        XCTAssertFalse(sut.isRestoring)
    }

    // MARK: - PiP Stop Tests (Normal - Not Restoring)

    func testPipDidStop_whenNotRestoring_clearsState() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        sut.pipDidStop()

        XCTAssertNil(sut.pipPlayer)
        XCTAssertNil(sut.pipItem)
        XCTAssertNil(sut.pipController)
        XCTAssertFalse(sut.isPiPActive)
        XCTAssertFalse(sut.shouldRestorePlayer)
    }

    func testPipDidStop_whenRestoring_preservesPlayer() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        // Enter the restoring state directly. The full requestRestoreUI flow
        // depends on UIKit presentation, which fails synchronously in unit
        // tests (no window scene); we exercise the state-machine contract here.
        sut.beginRestoration()

        sut.pipDidStop()

        // While restoring, pipDidStop must not clear the player/item/controller —
        // the restoring code path is responsible for handing them off.
        XCTAssertNotNil(sut.pipPlayer)
        XCTAssertNotNil(sut.pipItem)
        XCTAssertNotNil(sut.pipController)
        XCTAssertTrue(sut.isRestoring)
        XCTAssertFalse(sut.isPiPActive)
    }

    // MARK: - Restore UI Flow Tests

    func testRequestRestoreUI_withController_setsIsRestoring() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        // In test environment, completion is called immediately with false (no window)
        var completionResult: Bool?
        sut.requestRestoreUI { result in
            completionResult = result
        }

        // Should have attempted restoration
        XCTAssertNotNil(completionResult)
        // In test env without proper window, result is false
        XCTAssertFalse(completionResult ?? true)
    }

    func testRequestRestoreUI_withoutController_callsCompletionWithFalse() {
        // Don't call pipDidStart, so there's no controller
        var completionCalled = false
        var completionResult: Bool?

        sut.requestRestoreUI { result in
            completionCalled = true
            completionResult = result
        }

        XCTAssertTrue(completionCalled)
        XCTAssertEqual(completionResult, false)
    }

    func testSignalRestorationComplete_clearsRestoringState() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        // Manually set up restoration state for this test
        // (In real usage, requestRestoreUI would set this)
        sut.requestRestoreUI { _ in }

        sut.signalRestorationComplete()

        XCTAssertFalse(sut.isRestoring)
        XCTAssertFalse(sut.isPiPActive)
        XCTAssertFalse(sut.shouldRestorePlayer)
        // Player and controller should still be available for the restored view
        XCTAssertNotNil(sut.pipPlayer)
        XCTAssertNotNil(sut.pipController)
    }

    // MARK: - Edge Cases

    func testClearPlayer_clearsEverything() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)
        sut.requestRestoreUI { _ in }

        sut.clearPlayer()

        XCTAssertNil(sut.pipPlayer)
        XCTAssertNil(sut.pipItem)
        XCTAssertNil(sut.pipController)
        XCTAssertFalse(sut.isPiPActive)
        XCTAssertFalse(sut.isRestoring)
        XCTAssertFalse(sut.shouldRestorePlayer)
    }

    func testClearRestoreRequest_clearsShouldRestore() {
        let player = AVPlayer()
        let item = createTestMediaItem()
        let controller = AVPlayerViewController()
        sut.pipDidStart(player: player, item: item, controller: controller, delegate: mockDelegate)

        // Request restore sets shouldRestorePlayer = true before attempting presentation
        // but in tests it will be cleared quickly

        sut.clearRestoreRequest()

        XCTAssertFalse(sut.shouldRestorePlayer)
    }

    // MARK: - Helpers

    private func createTestMediaItem() -> MediaItem {
        MediaItem(
            id: "test-id-\(UUID().uuidString)",
            name: "Test Movie",
            type: .movie
        )
    }
}
