@testable import SeerUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class JellyseerrConnectCalloutSnapshotTests: XCTestCase {
    func testJellyseerrConnectCallout_Discover_iPhoneCompact() {
        let view = JellyseerrConnectCallout(
            title: "Discover Movies & Shows",
            description: "Connect Jellyseerr to browse trending content and request new media.",
            onConnectTapped: {}
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testJellyseerrConnectCallout_Requests_iPhoneCompact() {
        let view = JellyseerrConnectCallout(
            title: "Manage Requests",
            description: "Connect Jellyseerr to track and manage media requests.",
            onConnectTapped: {}
        )
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }
}
