@testable import NotificationClient
import XCTest

/// Transition table for `RequestStatusPoller.detectChange`.
///
/// Jellyseerr status values: 1 = pending, 2 = approved, 3 = declined,
/// 4 = available, 5 = processing.
final class RequestStatusPollerTests: XCTestCase {
    private func change(from old: Int, to new: Int) -> RequestStatusChange? {
        RequestStatusPoller.detectChange(oldStatus: old, newStatus: new, requestID: 7, title: "Title")
    }

    func testPendingToApproved_isApproved() {
        guard case let .approved(requestID, title)? = change(from: 1, to: 2) else {
            return XCTFail("Expected .approved")
        }
        XCTAssertEqual(requestID, 7)
        XCTAssertEqual(title, "Title")
    }

    func testPendingToDeclined_isDeclined() {
        guard case .declined? = change(from: 1, to: 3) else {
            return XCTFail("Expected .declined")
        }
    }

    func testApprovedToAvailable_isAvailable() {
        guard case .available? = change(from: 2, to: 4) else {
            return XCTFail("Expected .available")
        }
    }

    func testProcessingToAvailable_isAvailable() {
        guard case .available? = change(from: 5, to: 4) else {
            return XCTFail("Expected .available")
        }
    }

    func testTransitionsThatDoNotNotify_returnNil() {
        // Approved -> processing is an internal step, not user-facing
        XCTAssertNil(change(from: 2, to: 5))
        // Anything leaving "available" or "declined" is not announced
        XCTAssertNil(change(from: 4, to: 1))
        XCTAssertNil(change(from: 3, to: 2))
        // Pending straight to available skips the approval notification
        XCTAssertNil(change(from: 1, to: 4))
        // No change
        XCTAssertNil(change(from: 2, to: 2))
    }
}
