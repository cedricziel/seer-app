@testable import SeerApp
@testable import SeerCore
import XCTest

/// End-to-end tests for the Requests auto-refresh wiring:
/// - The scheduler stays idle when Jellyseerr isn't configured
/// - start/stop control the scheduler lifecycle
/// - silentRefresh tolerates a missing service without crashing
@MainActor
final class RequestsViewModelTests: XCTestCase {
    private var appState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
    }

    override func tearDown() async throws {
        appState = nil
        try await super.tearDown()
    }

    func testStartAutoRefresh_withoutConfiguredJellyseerr_doesNothing() {
        let scheduler = RefreshScheduler(interval: 0.5)
        let viewModel = RequestsViewModel(appState: appState, autoRefreshScheduler: scheduler)

        viewModel.startAutoRefresh()

        XCTAssertFalse(scheduler.isRunning,
                       "Scheduler must stay idle until Jellyseerr is configured")
    }

    func testStopAutoRefresh_isSafeWhenNotRunning() {
        let scheduler = RefreshScheduler(interval: 0.5)
        let viewModel = RequestsViewModel(appState: appState, autoRefreshScheduler: scheduler)

        // Should not throw or crash.
        viewModel.stopAutoRefresh()
        XCTAssertFalse(scheduler.isRunning)
    }

    func testSilentRefresh_withoutConfiguredService_returnsCleanly() async {
        let viewModel = RequestsViewModel(appState: appState)

        // No Jellyseerr service -> silentRefresh bails without touching state
        // and without throwing.
        await viewModel.silentRefresh()

        XCTAssertTrue(viewModel.requests.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testIsJellyseerrConfigured_falseByDefault() {
        let viewModel = RequestsViewModel(appState: appState)
        XCTAssertFalse(viewModel.isJellyseerrConfigured)
    }

    func testDefaultAutoRefreshInterval_isReasonable() {
        // Sanity check: 45s is short enough to feel live, long enough to
        // avoid hammering the server. If this constant changes, we want a
        // deliberate choice.
        XCTAssertEqual(RequestsViewModel.defaultAutoRefreshInterval, 45)
    }
}
