@testable import DownloadClient
import XCTest

final class DownloadStateTests: XCTestCase {
    // MARK: - displayName

    func testDisplayName_pending() {
        XCTAssertEqual(DownloadState.pending.displayName, "Waiting")
    }

    func testDisplayName_downloading() {
        XCTAssertEqual(DownloadState.downloading.displayName, "Downloading")
    }

    func testDisplayName_paused() {
        XCTAssertEqual(DownloadState.paused.displayName, "Paused")
    }

    func testDisplayName_waitingForWiFi() {
        XCTAssertEqual(DownloadState.waitingForWiFi.displayName, "Waiting for WiFi")
    }

    func testDisplayName_completed() {
        XCTAssertEqual(DownloadState.completed.displayName, "Downloaded")
    }

    func testDisplayName_failed() {
        XCTAssertEqual(DownloadState.failed.displayName, "Failed")
    }

    // MARK: - systemImage

    func testSystemImage_allStatesProvideName() {
        let allStates: [DownloadState] = [.pending, .downloading, .paused, .waitingForWiFi, .completed, .failed]
        for state in allStates {
            XCTAssertFalse(state.systemImage.isEmpty, "State \(state) should have an SF Symbol name")
        }
    }

    func testSystemImage_systemImagesAreUnique() {
        let images = Set([
            DownloadState.pending.systemImage,
            DownloadState.downloading.systemImage,
            DownloadState.paused.systemImage,
            DownloadState.waitingForWiFi.systemImage,
            DownloadState.completed.systemImage,
            DownloadState.failed.systemImage
        ])
        XCTAssertEqual(images.count, 6, "Each state should have a unique SF Symbol")
    }

    func testSystemImage_completedUsesCheckmarkVariant() {
        XCTAssertTrue(DownloadState.completed.systemImage.contains("checkmark"))
    }

    func testSystemImage_failedUsesExclamation() {
        XCTAssertTrue(DownloadState.failed.systemImage.contains("exclamationmark"))
    }

    // MARK: - Codable round-trip

    func testCodable_roundTrip() throws {
        let allStates: [DownloadState] = [.pending, .downloading, .paused, .waitingForWiFi, .completed, .failed]
        for state in allStates {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(DownloadState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testRawValues_areLowercaseStrings() {
        XCTAssertEqual(DownloadState.pending.rawValue, "pending")
        XCTAssertEqual(DownloadState.downloading.rawValue, "downloading")
        XCTAssertEqual(DownloadState.paused.rawValue, "paused")
        XCTAssertEqual(DownloadState.waitingForWiFi.rawValue, "waitingForWiFi")
        XCTAssertEqual(DownloadState.completed.rawValue, "completed")
        XCTAssertEqual(DownloadState.failed.rawValue, "failed")
    }
}
