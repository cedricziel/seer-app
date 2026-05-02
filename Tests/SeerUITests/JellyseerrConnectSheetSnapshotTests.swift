@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class JellyseerrConnectSheetSnapshotTests: XCTestCase {
    func testJellyseerrConnectSheet_iPhoneCompact_Empty() {
        let sheet = JellyseerrConnectSheet(
            connector: { _, _ in },
            onSuccess: {},
            onCancel: {}
        )
        assertSnapshot(of: sheet, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13)))
    }

    func testJellyseerrConnectSheet_iPadRegular() {
        let sheet = JellyseerrConnectSheet(
            connector: { _, _ in },
            onSuccess: {},
            onCancel: {}
        )
        assertSnapshot(of: sheet, as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPadPro11)))
    }
}
