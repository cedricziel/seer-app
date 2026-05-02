import Foundation
@testable import SeerCore
import XCTest

/// 6.4a — assertion that the indexing flag is per-device, NOT
/// mirrored to iCloud KVS. Matches the
/// `app-intents-foundation` spec scenario: "Indexing flag does
/// not sync between devices."
@MainActor
final class AppStateIndexingFlagTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // Clean any KVS state from prior tests.
        NSUbiquitousKeyValueStore.default.removeObject(
            forKey: AppState.AppIntentsKeys.indexingEnabled
        )
        UserDefaults.standard.removeObject(
            forKey: AppState.AppIntentsKeys.indexingEnabled
        )
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(
            forKey: AppState.AppIntentsKeys.indexingEnabled
        )
        NSUbiquitousKeyValueStore.default.removeObject(
            forKey: AppState.AppIntentsKeys.indexingEnabled
        )
        try await super.tearDown()
    }

    func testIndexingFlagIsNotMirroredToICloudKVS() {
        let appState = AppState()
        appState.appIntentsIndexingEnabled = true

        // It MUST land in UserDefaults.
        XCTAssertTrue(
            UserDefaults.standard.bool(
                forKey: AppState.AppIntentsKeys.indexingEnabled
            )
        )

        // It MUST NOT land in iCloud KVS.
        XCTAssertNil(
            NSUbiquitousKeyValueStore.default.object(
                forKey: AppState.AppIntentsKeys.indexingEnabled
            ),
            "Spotlight indexing flag is per-device — must not sync via iCloud KVS"
        )
    }

    func testFlagDefaultsToFalseOnFreshInstall() {
        let appState = AppState()
        XCTAssertFalse(appState.appIntentsIndexingEnabled)
    }
}
