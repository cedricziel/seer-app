@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class WelcomeViewSnapshotTests: XCTestCase {
    func testWelcomeView_iPhoneCompact_FreshInstall() {
        let view = WelcomeView(
            primarySuggestion: nil,
            secondarySuggestions: [],
            onSelectSuggestion: { _ in },
            onManualEntry: {}
        )
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testWelcomeView_iPhoneCompact_WithBonjourSuggestion() {
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
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testWelcomeView_iPadRegular_WithSyncedSuggestion() {
        let view = WelcomeView(
            primarySuggestion: WelcomeView.Suggestion(
                id: "synced-1",
                title: "MacMini",
                subtitle: "Sign back in",
                symbolName: "icloud.fill"
            ),
            secondarySuggestions: [],
            onSelectSuggestion: { _ in },
            onManualEntry: {}
        )
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPadPro11)))
    }
}
