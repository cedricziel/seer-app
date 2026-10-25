@testable import SeerApp
import SeerCore
import SnapshotTesting
import SwiftData
import SwiftUI
import XCTest

@MainActor
final class JellyseerrSurfaceSnapshotTests: XCTestCase {
    private var appState: AppState!
    private var modelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([ServerConfiguration.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    func testSearchView_Library_iPhoneCompact() throws {
        let view = try SearchView()
            .environmentObject(XCTUnwrap(appState))
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testSettingsView_iPhoneCompact() throws {
        let view = try SettingsView()
            .environmentObject(XCTUnwrap(appState))
        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }
}
