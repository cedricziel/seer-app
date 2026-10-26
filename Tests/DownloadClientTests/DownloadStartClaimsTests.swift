@testable import DownloadClient
import Foundation
import SwiftData
import XCTest

final class DownloadStartClaimsTests: XCTestCase {
    func testPausedStartCannotContinueAfterPlaybackInfoReturns() {
        var claims = DownloadStartClaims()
        let downloadID = UUID()
        let starting = claims.begin(downloadID)

        claims.invalidate(downloadID)

        XCTAssertFalse(claims.isCurrent(starting, for: downloadID))
    }

    func testRequeuedStartSupersedesPendingPlaybackInfo() {
        var claims = DownloadStartClaims()
        let downloadID = UUID()
        let original = claims.begin(downloadID)
        claims.invalidate(downloadID)

        let replacement = claims.begin(downloadID)
        claims.finish(original, for: downloadID)

        XCTAssertFalse(claims.isCurrent(original, for: downloadID))
        XCTAssertTrue(claims.isCurrent(replacement, for: downloadID))
    }

    func testCancellationDoesNotInvalidateAnotherDownload() {
        var claims = DownloadStartClaims()
        let firstID = UUID()
        let secondID = UUID()
        _ = claims.begin(firstID)
        let second = claims.begin(secondID)

        claims.invalidate(firstID)

        XCTAssertTrue(claims.isCurrent(second, for: secondID))
    }

    func testStaleTaskCleanupDoesNotClearReplacementTask() async throws {
        let schema = Schema([Download.self, AutoDownloadRule.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let store = DownloadStore(modelContainer: container)
        let download = Download(
            serverID: "server",
            itemID: "movie",
            mediaSourceID: "source",
            name: "Movie",
            mediaType: "Movie"
        )
        try await store.insert(download)
        try await store.updateTaskIdentifier(downloadID: download.id, taskIdentifier: 2)

        try await store.clearTaskIdentifier(downloadID: download.id, matching: 1)

        let persisted = try await store.fetchDownload(id: download.id)
        XCTAssertEqual(persisted?.taskIdentifier, 2)
    }
}
