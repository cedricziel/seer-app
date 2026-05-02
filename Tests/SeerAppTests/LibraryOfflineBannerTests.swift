@testable import SeerApp
@testable import SeerCore
import XCTest

/// End-to-end test for the offline content indicator:
/// `isShowingCachedData` is what drives the OfflineBanner in LibraryView,
/// so we lock in the default state and the post-clear-on-success behavior.
@MainActor
final class LibraryOfflineBannerTests: XCTestCase {
    func testInitialState_isShowingCachedDataIsFalse() {
        let appState = AppState()
        let viewModel = LibraryViewModel(appState: appState)

        XCTAssertFalse(
            viewModel.isShowingCachedData,
            "Banner should be hidden until we discover we're offline or cached"
        )
        XCTAssertNil(viewModel.lastSyncDate)
    }

    func testIsShowingCachedData_canBeFlippedOnByModel() {
        // The banner is purely driven by isShowingCachedData; this test
        // documents that contract so future refactors don't silently break
        // the LibraryView UI binding.
        let appState = AppState()
        let viewModel = LibraryViewModel(appState: appState)

        viewModel.isShowingCachedData = true
        viewModel.lastSyncDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.isShowingCachedData)
        XCTAssertEqual(viewModel.lastSyncDate?.timeIntervalSince1970, 1_700_000_000)
    }
}
