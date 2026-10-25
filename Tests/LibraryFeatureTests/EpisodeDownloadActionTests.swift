@testable import SeerApp
import SeerUI
import XCTest

@MainActor
final class EpisodeDownloadActionTests: XCTestCase {
    func testPausedDownloadUsesResumeAction() {
        assertAction(state: .paused, downloads: 1, cancellations: 0)
    }

    func testFailedDownloadUsesRetryAction() {
        assertAction(state: .failed, downloads: 1, cancellations: 0)
    }

    func testActiveDownloadUsesCancelAction() {
        assertAction(state: .downloading(progress: 0.5), downloads: 0, cancellations: 1)
    }

    func testPendingDownloadUsesCancelAction() {
        assertAction(state: .pending, downloads: 0, cancellations: 1)
    }

    private func assertAction(state: DownloadButtonState, downloads: Int, cancellations: Int) {
        var downloadCount = 0
        var cancelCount = 0
        let button = CompactDownloadButton(
            state: state, onDownload: { downloadCount += 1 }, onCancel: { cancelCount += 1 }
        )
        button.performAction()
        XCTAssertEqual(downloadCount, downloads)
        XCTAssertEqual(cancelCount, cancellations)
    }
}
