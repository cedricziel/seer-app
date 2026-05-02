@testable import OfflineSync
import SeerCore
import SwiftData
import XCTest

final class ConflictResolverTests: XCTestCase {
    let resolver = ConflictResolver()

    // MARK: - Position Resolution

    func testResolveProgress_localGreaterThanServer_takesLocalPosition() {
        let local = makeProgress(positionTicks: 5_000_000_000)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: 1_000_000_000,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 5_000_000_000)
    }

    func testResolveProgress_serverGreaterThanLocal_takesServerPosition() {
        let local = makeProgress(positionTicks: 1_000_000_000)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: 7_000_000_000,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 7_000_000_000)
    }

    func testResolveProgress_equalPositions_takesEither() {
        let local = makeProgress(positionTicks: 3_000_000_000)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: 3_000_000_000,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 3_000_000_000)
    }

    func testResolveProgress_noLocal_serverPosition_takesServer() {
        let resolved = resolver.resolveProgress(
            local: nil,
            serverPosition: 4_000_000_000,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 4_000_000_000)
    }

    func testResolveProgress_localOnly_noServer_takesLocal() {
        let local = makeProgress(positionTicks: 8_000_000_000)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 8_000_000_000)
    }

    func testResolveProgress_neitherSet_returnsZero() {
        let resolved = resolver.resolveProgress(
            local: nil,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 0)
    }

    // MARK: - Favorite Resolution

    func testResolveProgress_pendingLocalFavorite_keepsLocalValue() {
        let local = makeProgress(isFavorite: true, syncStatus: .pending)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: false,
            serverIsPlayed: nil
        )
        // Pending local change wins over server
        XCTAssertTrue(resolved.isFavorite)
    }

    func testResolveProgress_completedLocalFavorite_takesServerValue() {
        let local = makeProgress(isFavorite: false, syncStatus: .completed)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: true,
            serverIsPlayed: nil
        )
        XCTAssertTrue(resolved.isFavorite)
    }

    func testResolveProgress_noLocal_takesServerFavorite() {
        let resolved = resolver.resolveProgress(
            local: nil,
            serverPosition: nil,
            serverIsFavorite: true,
            serverIsPlayed: nil
        )
        XCTAssertTrue(resolved.isFavorite)
    }

    func testResolveProgress_noServerFavorite_defaultsToFalse() {
        let resolved = resolver.resolveProgress(
            local: nil,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertFalse(resolved.isFavorite)
    }

    // MARK: - Played Resolution

    func testResolveProgress_pendingLocalPlayed_keepsLocalValue() {
        let local = makeProgress(isPlayed: true, syncStatus: .pending)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: false
        )
        XCTAssertTrue(resolved.isPlayed)
    }

    func testResolveProgress_failedLocalPlayed_takesServerValue() {
        // Only "pending" sync status preserves local; failed/completed/syncing yield to server
        let local = makeProgress(isPlayed: false, syncStatus: .failed)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: true
        )
        XCTAssertTrue(resolved.isPlayed)
    }

    func testResolveProgress_syncingLocalPlayed_takesServerValue() {
        let local = makeProgress(isPlayed: false, syncStatus: .syncing)
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: true
        )
        XCTAssertTrue(resolved.isPlayed)
    }

    func testResolveProgress_noServerPlayed_defaultsToFalse() {
        let resolved = resolver.resolveProgress(
            local: nil,
            serverPosition: nil,
            serverIsFavorite: nil,
            serverIsPlayed: nil
        )
        XCTAssertFalse(resolved.isPlayed)
    }

    // MARK: - Combined Scenarios

    func testResolveProgress_pendingMultipleFlags_allLocalWin() {
        let local = makeProgress(
            positionTicks: 9_000_000_000,
            isFavorite: true,
            isPlayed: true,
            syncStatus: .pending
        )
        let resolved = resolver.resolveProgress(
            local: local,
            serverPosition: 1_000_000_000,
            serverIsFavorite: false,
            serverIsPlayed: false
        )
        XCTAssertEqual(resolved.playbackPositionTicks, 9_000_000_000)
        XCTAssertTrue(resolved.isFavorite)
        XCTAssertTrue(resolved.isPlayed)
    }

    // MARK: - Helpers

    private func makeProgress(
        positionTicks: Int64 = 0,
        isFavorite: Bool = false,
        isPlayed: Bool = false,
        syncStatus: SyncStatus = .pending
    ) -> CachedUserProgress {
        CachedUserProgress(
            mediaItemId: "media-1",
            serverConfigurationID: UUID(),
            playbackPositionTicks: positionTicks,
            isFavorite: isFavorite,
            isPlayed: isPlayed,
            syncStatus: syncStatus.rawValue
        )
    }
}
