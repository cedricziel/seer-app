@testable import PlaybackClient
import XCTest

final class PlaybackStateTests: XCTestCase {
    // MARK: - positionSeconds

    func testPositionSeconds_oneSecond() {
        let state = makeState(positionTicks: 10_000_000)
        XCTAssertEqual(state.positionSeconds, 1.0, accuracy: 0.0001)
    }

    func testPositionSeconds_zero() {
        let state = makeState(positionTicks: 0)
        XCTAssertEqual(state.positionSeconds, 0.0)
    }

    func testPositionSeconds_thirtyFiveAndAHalfSeconds() {
        let state = makeState(positionTicks: 355_000_000)
        XCTAssertEqual(state.positionSeconds, 35.5, accuracy: 0.0001)
    }

    // MARK: - positionTicks(from:)

    func testPositionTicksFromSeconds_zero() {
        XCTAssertEqual(PlaybackState.positionTicks(from: 0), 0)
    }

    func testPositionTicksFromSeconds_oneSecond() {
        XCTAssertEqual(PlaybackState.positionTicks(from: 1.0), 10_000_000)
    }

    func testPositionTicksFromSeconds_roundTrip() {
        let originalTicks: Int64 = 12_345_670
        let seconds = Double(originalTicks) / 10_000_000.0
        XCTAssertEqual(PlaybackState.positionTicks(from: seconds), originalTicks)
    }

    // MARK: - withPosition

    func testWithPosition_updatesPositionOnly() {
        let original = makeState(positionTicks: 100, isPaused: true, volumeLevel: 50)
        let updated = original.withPosition(ticks: 5_000)

        XCTAssertEqual(updated.positionTicks, 5_000)
        XCTAssertEqual(updated.isPaused, true)
        XCTAssertEqual(updated.volumeLevel, 50)
        XCTAssertEqual(updated.itemId, original.itemId)
        XCTAssertEqual(updated.mediaSourceId, original.mediaSourceId)
    }

    // MARK: - withPaused

    func testWithPaused_updatesPausedOnly() {
        let original = makeState(positionTicks: 100, isPaused: false, volumeLevel: 50)
        let updated = original.withPaused(true)

        XCTAssertTrue(updated.isPaused)
        XCTAssertEqual(updated.positionTicks, 100)
        XCTAssertEqual(updated.volumeLevel, 50)
    }

    func testWithPaused_togglesBackToFalse() {
        let original = makeState(isPaused: true)
        let updated = original.withPaused(false)
        XCTAssertFalse(updated.isPaused)
    }

    // MARK: - PlayMethod

    func testPlayMethod_rawValuesMatchAPI() {
        XCTAssertEqual(PlaybackState.PlayMethod.directPlay.rawValue, "DirectPlay")
        XCTAssertEqual(PlaybackState.PlayMethod.directStream.rawValue, "DirectStream")
        XCTAssertEqual(PlaybackState.PlayMethod.transcode.rawValue, "Transcode")
    }

    // MARK: - Default Initializer Values

    func testInitializer_defaultsToReasonableValues() {
        let state = PlaybackState(
            itemId: "i",
            mediaSourceId: "m",
            playSessionId: nil,
            positionTicks: 0
        )
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isMuted)
        XCTAssertEqual(state.volumeLevel, 100)
        XCTAssertEqual(state.playMethod, .directPlay)
    }

    // MARK: - Helpers

    private func makeState(
        positionTicks: Int64 = 0,
        isPaused: Bool = false,
        volumeLevel: Int = 100
    ) -> PlaybackState {
        PlaybackState(
            itemId: "item-1",
            mediaSourceId: "source-1",
            playSessionId: "session-1",
            positionTicks: positionTicks,
            isPaused: isPaused,
            isMuted: false,
            volumeLevel: volumeLevel,
            playMethod: .directPlay
        )
    }
}
