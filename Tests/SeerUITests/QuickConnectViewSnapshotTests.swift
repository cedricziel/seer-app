@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class QuickConnectViewSnapshotTests: XCTestCase {
    func testQuickConnectView_iPhoneCompact_Polling() {
        let view = QuickConnectView(
            code: "473819",
            serverHost: "macmini.local",
            isPolling: true,
            onUsePassword: {},
            onCancel: {},
            onCopyCode: { true }
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testQuickConnectView_iPhoneCompact_Expired() {
        let view = QuickConnectView(
            code: nil,
            serverHost: "macmini.local",
            isPolling: false,
            errorMessage: "Code expired. Request a new code to try again.",
            onRetry: {},
            onUsePassword: {},
            onCancel: {},
            onCopyCode: { true }
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testQuickConnectView_iPhoneCompact_Failed() {
        let view = QuickConnectView(
            code: "OLD123",
            serverHost: "macmini.local",
            isPolling: false,
            errorMessage: "Network error: The server could not be reached.",
            onRetry: {},
            onUsePassword: {},
            onCancel: {},
            onCopyCode: { true }
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testQuickConnectView_iPhoneCompact_RequestingReplacement() {
        let view = QuickConnectView(
            code: nil,
            serverHost: "macmini.local",
            isPolling: true,
            onUsePassword: {},
            onCancel: {},
            onCopyCode: { true }
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }
}
