@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class ManualServerEntryViewSnapshotTests: XCTestCase {
    func testManualServerEntryView_iPhoneCompact_Empty() {
        let view = NavigationStack {
            ManualServerEntryView(
                url: .constant(""),
                isValidating: false,
                errorMessage: nil,
                onContinue: {}
            )
        }
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13)))
    }

    func testManualServerEntryView_iPhoneCompact_WithError() {
        let view = NavigationStack {
            ManualServerEntryView(
                url: .constant("https://not-jellyfin.example.com"),
                isValidating: false,
                errorMessage: "This URL doesn't look like a Jellyfin server.",
                onContinue: {}
            )
        }
        assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13)))
    }
}
