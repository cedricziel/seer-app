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
            onCopyCode: {}
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }
}
