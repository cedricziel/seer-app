@testable import SeerApp
import SeerCore
import SnapshotTesting
import SwiftData
import SwiftUI
import XCTest

/// Surface-level snapshot tests for the three feature views that render
/// the deferred-Jellyseerr connect prompt: Discover, Requests, Search.
/// Component-level rendering is covered by
/// `JellyseerrConnectCalloutSnapshotTests` in SeerUITests; these tests
/// pin the prompt embedded in each feature's NavigationStack + toolbar.
@MainActor
final class JellyseerrSurfaceSnapshotTests: XCTestCase {
    private var appState: AppState!
    private var modelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        // In-memory SwiftData container so the test doesn't touch the
        // user's CloudKit-backed store. With no servers added,
        // `appState.jellyseerrServerURL` is nil and every feature view
        // renders its `notConfiguredView` branch.
        let schema = Schema([ServerConfiguration.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        appState = AppState()
        appState.setModelContext(ModelContext(modelContainer))
    }

    override func tearDown() async throws {
        appState = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testDiscoverView_NotConfigured_iPhoneCompact() throws {
        let view = try DiscoverView()
            .environmentObject(XCTUnwrap(appState))
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testRequestsView_NotConfigured_iPhoneCompact() throws {
        let view = try RequestsView()
            .environmentObject(XCTUnwrap(appState))
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testSearchView_NotConfigured_iPhoneCompact() throws {
        let view = try SearchView()
            .environmentObject(XCTUnwrap(appState))
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }
}
