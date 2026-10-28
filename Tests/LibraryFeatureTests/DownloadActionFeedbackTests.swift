import Foundation
@testable import SeerApp
import XCTest

@MainActor
final class DownloadActionFeedbackTests: XCTestCase {
    func testFailedActionExposesLocalizedReason() async {
        let feedback = DownloadActionFeedback()

        await feedback.perform { throw Failure.diskFull }

        XCTAssertEqual(feedback.message, "Free up storage, then retry.")
    }

    func testSuccessfulActionRunsWithoutPresentingError() async {
        let feedback = DownloadActionFeedback()
        var completed = false

        await feedback.perform { completed = true }

        XCTAssertTrue(completed)
        XCTAssertNil(feedback.message)
    }

    func testDismissedErrorCanBePresentedAgain() async {
        let feedback = DownloadActionFeedback()
        await feedback.perform { throw Failure.diskFull }
        feedback.message = nil

        await feedback.perform { throw Failure.diskFull }

        XCTAssertEqual(feedback.message, "Free up storage, then retry.")
    }

    private enum Failure: LocalizedError {
        case diskFull

        var errorDescription: String? {
            "Free up storage, then retry."
        }
    }
}
