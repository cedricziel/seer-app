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
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13)))
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
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13)))
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
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPadPro11)))
    }

    func testWelcomeView_iPhoneCompact_Landscape() {
        let view = WelcomeView(
            primarySuggestion: WelcomeView.Suggestion(
                id: "bonjour-1",
                title: "Mac mini",
                subtitle: "macmini.local · on this Wi-Fi",
                symbolName: "wifi"
            ),
            secondarySuggestions: [],
            onSelectSuggestion: { _ in },
            onManualEntry: {}
        )
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13(.landscape))))
    }

    func testWelcomeView_iPadRegular_TwoThirdsSplit() {
        // Simulates the user putting the app in a 2/3 split on iPad — the
        // available width (~796pt on iPad Pro 11 landscape) is still in the
        // regular horizontal size class, so the welcome screen should keep
        // its side-by-side layout.
        let view = WelcomeView(
            primarySuggestion: WelcomeView.Suggestion(
                id: "synced-1",
                title: "MacMini",
                subtitle: "Sign back in",
                symbolName: "icloud.fill"
            ),
            secondarySuggestions: [
                WelcomeView.Suggestion(
                    id: "bonjour-1",
                    title: "Spare Pi",
                    subtitle: "raspberrypi.local · on this Wi-Fi",
                    symbolName: "wifi"
                )
            ],
            onSelectSuggestion: { _ in },
            onManualEntry: {}
        )
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)

        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .fixed(width: 796, height: 834)))
    }
}
