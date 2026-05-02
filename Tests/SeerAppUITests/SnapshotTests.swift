import XCTest

/// UI test that drives the app through onboarding (using Jellyfin's public
/// demo server) and captures App Store screenshots at key tab destinations.
///
/// Run via `make fastlane-screenshots`. Output lands in
/// `fastlane/screenshots/<locale>/<device>/`.
///
/// Brittleness notes: this test depends on the public Jellyfin demo at
/// https://demo.jellyfin.org/stable being reachable and populated. If the
/// demo server is down or its content changes, the waits will hit their
/// timeouts and the screenshot will capture whatever's on screen. That's
/// fine for a manual run — re-run when the demo is healthy. For CI
/// reliability, consider a launch-arg-driven fixture mode instead.
@MainActor
final class SnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testCaptureScreenshots() {
        let app = XCUIApplication()

        connectToDemoJellyfin(app: app)
        skipJellyseerr(app: app)
        snapshotLibrary(app: app)
        snapshotSearch(app: app)
        snapshotDownloads(app: app)
    }

    // MARK: - Onboarding

    private func connectToDemoJellyfin(app: XCUIApplication) {
        let serverField = app.textFields["Server URL"]
        guard serverField.waitForExistence(timeout: 15) else {
            XCTFail("Server URL field never appeared — is onboarding gated behind something else?")
            return
        }

        serverField.tap()
        serverField.typeText("https://demo.jellyfin.org/stable")

        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("demo")

        // Password is intentionally left empty — the public demo doesn't require one.

        app.buttons["Connect"].tap()
    }

    private func skipJellyseerr(app: XCUIApplication) {
        let skipButton = app.buttons["Skip for Now"]
        // Wait generously — Jellyfin connection can be slow against the public demo.
        if skipButton.waitForExistence(timeout: 45) {
            skipButton.tap()
        }
    }

    // MARK: - Tab screenshots

    private func snapshotLibrary(app: XCUIApplication) {
        // Library tab is the default landing tab; just wait for any media tile to render.
        // Cards typically expose their title as an accessibility label, so look for the
        // collection-style scroll view first then settle for the tab bar's existence.
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 30)
        snapshot("01-Library")
    }

    private func snapshotSearch(app: XCUIApplication) {
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.waitForExistence(timeout: 5) {
            searchTab.tap()
        }

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("the")
            // Let the debounced search fire and results render.
            sleep(3)
        }
        snapshot("02-Search")
    }

    private func snapshotDownloads(app: XCUIApplication) {
        let downloadsTab = app.tabBars.buttons["Downloads"]
        if downloadsTab.waitForExistence(timeout: 5) {
            downloadsTab.tap()
            sleep(1)
        }
        snapshot("03-Downloads")
    }
}
