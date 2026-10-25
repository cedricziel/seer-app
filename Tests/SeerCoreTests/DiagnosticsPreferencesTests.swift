import Foundation
@testable import SeerCore
import XCTest

final class DiagnosticsPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "seer.diagnostics.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testFreshInstallEnablesDiagnostics() {
        let preferences = DiagnosticsPreferences(defaults: defaults)
        XCTAssertTrue(preferences.crashReportsEnabled)
        XCTAssertTrue(preferences.performanceMetricsEnabled)
    }

    func testExistingOptOutSurvivesDefaultChangeAndRelaunch() {
        defaults.set(false, forKey: "diagnostics.crashReportsEnabled")
        defaults.set(false, forKey: "diagnostics.performanceMetricsEnabled")
        let preferences = DiagnosticsPreferences(defaults: defaults)
        XCTAssertFalse(preferences.crashReportsEnabled)
        XCTAssertFalse(preferences.performanceMetricsEnabled)
    }

    func testLegacyDeclinePreservesMissingCategoryAsDisabled() {
        defaults.set(true, forKey: "diagnostics.hasShownConsentPrompt")
        defaults.set(true, forKey: "diagnostics.crashReportsEnabled")
        let preferences = DiagnosticsPreferences(defaults: defaults)
        XCTAssertTrue(preferences.crashReportsEnabled)
        XCTAssertFalse(preferences.performanceMetricsEnabled)
    }

    func testSettingsChangesPersistIndependently() {
        let preferences = DiagnosticsPreferences(defaults: defaults)
        preferences.performanceMetricsEnabled = false
        let relaunched = DiagnosticsPreferences(defaults: defaults)
        XCTAssertTrue(relaunched.crashReportsEnabled)
        XCTAssertFalse(relaunched.performanceMetricsEnabled)
    }
}
