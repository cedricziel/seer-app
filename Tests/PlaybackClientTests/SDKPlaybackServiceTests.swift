import Foundation
@testable import PlaybackClient
import XCTest

@MainActor
final class SDKPlaybackServiceTests: XCTestCase {
    func testNegotiationKeepsEveryProfileFieldAndOmission() async throws {
        let server = SDKStubServer(status: 200, body: #"{"MediaSources":[],"PlaySessionId":"session-1"}"#)
        let service = playbackService(server)

        let response = try await service.getPlaybackInfo(itemId: "item-1", startPositionTicks: 9_007_199_254_740_993)

        let profile = try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(DeviceProfileBuilder.buildAppleDeviceProfile()))
        let expected: [String: Any] = [
            "UserId": "user-1",
            "MaxStreamingBitrate": 120_000_000,
            "StartTimeTicks": Int64(9_007_199_254_740_993),
            "DeviceProfile": profile,
            "AutoOpenLiveStream": true
        ]
        XCTAssertEqual(try body(server, at: 0), expected as NSDictionary)
        XCTAssertEqual(server.requests.first?.httpMethod, "POST")
        XCTAssertEqual(server.requests.first?.url?.path, "/jellyfin/Items/item-1/PlaybackInfo")
        XCTAssertEqual(response.playSessionId, "session-1")
    }

    func testPlaybackStartKeepsExactStatePayload() async throws {
        let server = SDKStubServer(status: 204, body: "")
        let state = PlaybackState(
            itemId: "item-1", mediaSourceId: "source-1", playSessionId: "session-1",
            positionTicks: 9_007_199_254_740_993, playMethod: .directStream
        )

        try await playbackService(server).reportPlaybackStart(state: state)

        XCTAssertEqual(try body(server, at: 0), [
            "CanSeek": true,
            "ItemId": "item-1",
            "MediaSourceId": "source-1",
            "PlaySessionId": "session-1",
            "PositionTicks": Int64(9_007_199_254_740_993),
            "PlayMethod": "DirectStream"
        ] as NSDictionary)
        XCTAssertEqual(server.requests.first?.url?.path, "/jellyfin/Sessions/Playing")
    }

    func testPlaybackProgressKeepsExactStatePayload() async throws {
        let server = SDKStubServer(status: 204, body: "")
        let state = PlaybackState(
            itemId: "item-1", mediaSourceId: "source-1", playSessionId: "session-1",
            positionTicks: 9_007_199_254_740_993, isPaused: true, isMuted: true,
            volumeLevel: 42, playMethod: .transcode
        )

        try await playbackService(server).reportPlaybackProgress(state: state)

        XCTAssertEqual(try body(server, at: 0), [
            "CanSeek": true,
            "ItemId": "item-1",
            "MediaSourceId": "source-1",
            "PlaySessionId": "session-1",
            "PositionTicks": Int64(9_007_199_254_740_993),
            "IsPaused": true,
            "IsMuted": true,
            "VolumeLevel": 42,
            "PlayMethod": "Transcode"
        ] as NSDictionary)
        XCTAssertEqual(server.requests.first?.url?.path, "/jellyfin/Sessions/Playing/Progress")
    }

    func testPlaybackStopDoesNotMaterializeOmittedFlagsOrSession() async throws {
        let server = SDKStubServer(status: 204, body: "")
        let state = PlaybackState(itemId: "item-1", mediaSourceId: "source-1", playSessionId: nil, positionTicks: 100)

        try await playbackService(server).reportPlaybackStopped(state: state)

        XCTAssertEqual(try body(server, at: 0), [
            "ItemId": "item-1", "MediaSourceId": "source-1", "PositionTicks": 100
        ] as NSDictionary)
        XCTAssertEqual(server.requests.first?.url?.path, "/jellyfin/Sessions/Playing/Stopped")
    }

    func testPlaybackReportsRetainNoncriticalServerFailureBehavior() async throws {
        let server = SDKStubServer(status: 503, body: "Unavailable")
        let state = PlaybackState(itemId: "item-1", mediaSourceId: "source-1", playSessionId: nil, positionTicks: 100)

        try await playbackService(server).reportPlaybackProgress(state: state)

        XCTAssertEqual(server.requests.count, 1)
    }

    func testPlaybackNegotiationRetainsServerErrorBody() async throws {
        let server = SDKStubServer(status: 403, body: "Playback denied")
        do {
            _ = try await playbackService(server).getPlaybackInfo(itemId: "item-1")
            XCTFail("Expected playback failure")
        } catch let PlaybackService.PlaybackError.serverError(status, body) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(body, "Playback denied")
        }
    }

    private func playbackService(_ server: SDKStubServer) -> PlaybackService {
        PlaybackService(
            serverURL: server.url,
            accessToken: "TOKEN-1",
            userID: "user-1",
            deviceID: "device-1",
            sessionConfiguration: server.configuration
        )
    }

    private func body(_ server: SDKStubServer, at index: Int) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: server.bodies[index]) as? NSDictionary)
    }
}
