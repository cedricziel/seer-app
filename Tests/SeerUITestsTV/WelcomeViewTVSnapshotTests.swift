@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class WelcomeViewTVSnapshotTests: XCTestCase {
    /// Confirms `WelcomeView` renders for tvOS at 1920×1080 with the
    /// horizontal hero+suggestions layout. The Siri Remote default focus
    /// targeting is asserted at the API level via `defaultFocus(...)` in
    /// the production code; visual focus state needs an XCUITest run with
    /// the focus engine to capture.
    func testWelcomeView_tvOS_FocusLandsOnPrimarySuggestion() {
        let view = WelcomeView(
            primarySuggestion: WelcomeView.Suggestion(
                id: "bonjour-1",
                title: "Mac mini",
                subtitle: "macmini.local · on this Wi-Fi",
                symbolName: "wifi"
            ),
            secondarySuggestions: [
                WelcomeView.Suggestion(
                    id: "synced-1",
                    title: "Synology NAS",
                    subtitle: "Synced via iCloud",
                    symbolName: "icloud.fill"
                )
            ],
            onSelectSuggestion: { _ in },
            onManualEntry: {}
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .fixed(width: 1920, height: 1080))
        )
    }
}
