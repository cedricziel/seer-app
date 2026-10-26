import BackgroundTasks
@testable import SeerApp
import XCTest

@MainActor
final class RequestPollingSchedulingTests: XCTestCase {
    func testAuthenticatedBackgroundLaunchReschedulesBeforePollerExists() {
        let delegate = SeerAppDelegate()
        delegate.requestPollingAllowed = { true }
        var scheduledIdentifier: String?

        delegate.scheduleRequestPollTask { scheduledIdentifier = $0.identifier }

        XCTAssertNil(delegate.requestStatusPoller)
        XCTAssertEqual(scheduledIdentifier, SeerAppDelegate.requestPollTaskIdentifier)
    }

    func testLoggedOutSessionDoesNotScheduleBackgroundPolling() {
        let delegate = SeerAppDelegate()
        delegate.requestPollingAllowed = { false }
        var submitted = false

        delegate.scheduleRequestPollTask { _ in submitted = true }

        XCTAssertFalse(submitted)
    }
}
