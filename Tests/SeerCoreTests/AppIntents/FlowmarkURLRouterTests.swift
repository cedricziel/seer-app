@testable import SeerCore
import XCTest

@MainActor
final class FlowmarkURLRouterTests: XCTestCase {
    /// 6.7 — flowmark://media/<id> opens the player target.
    func testRoutesMediaURLToPlayer() throws {
        let router = FlowmarkURLRouter()
        let url = try XCTUnwrap(URL(string: "flowmark://media/abc-123"))
        let result = router.route(url)

        XCTAssertEqual(result, .openMedia(id: "abc-123"))
        XCTAssertEqual(router.pendingMedia?.itemID, "abc-123")
        XCTAssertEqual(router.selectedTab, .library)
    }

    /// 6.8 — flowmark://library opens the Library tab.
    func testRoutesLibraryURLToLibraryTab() throws {
        let router = FlowmarkURLRouter()
        let url = try XCTUnwrap(URL(string: "flowmark://library"))
        let result = router.route(url)

        XCTAssertEqual(result, .openLibrary)
        XCTAssertNil(router.pendingMedia)
        XCTAssertEqual(router.selectedTab, .library)
    }

    /// 6.9 — Unknown path is a no-op (does not throw, does not change state).
    func testIgnoresUnknownPath() throws {
        let router = FlowmarkURLRouter()
        router.selectedTab = .discover
        try router.route(XCTUnwrap(URL(string: "flowmark://media/preserved")))
        router.selectedTab = .discover

        let url = try XCTUnwrap(URL(string: "flowmark://requests/42"))
        let result = router.route(url)

        if case .unknown = result {} else {
            XCTFail("Expected .unknown, got \(result)")
        }
        XCTAssertEqual(router.selectedTab, .discover)
        XCTAssertEqual(router.pendingMedia?.itemID, "preserved")
    }

    func testConsumesMediaIntoNavigationOnlyOnce() async {
        let router = FlowmarkURLRouter()
        let serverID = UUID()
        router.selectedTab = .search
        router.route(ResumeWatchingIntent.mediaURL(for: "shared", serverID: serverID))
        var opened: [String] = []

        await router.consumePendingMedia { route in
            XCTAssertEqual(route.serverID, serverID)
            return route.itemID
        } open: { opened.append($0) }
        await router.consumePendingMedia { $0.itemID } open: { opened.append($0) }

        XCTAssertEqual(router.selectedTab, .library)
        XCTAssertEqual(opened, ["shared"])
        XCTAssertNil(router.pendingMedia)
    }

    func testSupersededLookupCannotOpenOldDetail() async throws {
        let router = FlowmarkURLRouter()
        try router.route(XCTUnwrap(URL(string: "flowmark://media/old")))
        var opened: [String] = []

        await router.consumePendingMedia { route in
            router.route(ResumeWatchingIntent.libraryURL)
            return route.itemID
        } open: { opened.append($0) }

        XCTAssertTrue(opened.isEmpty)
        XCTAssertNil(router.pendingMedia)
    }

    func testFailedLookupKeepsRouteForRetry() async throws {
        let router = FlowmarkURLRouter()
        try router.route(XCTUnwrap(URL(string: "flowmark://media/missing")))
        await router.consumePendingMedia { _ -> String? in nil } open: { _ in XCTFail("Missing item opened") }
        XCTAssertEqual(router.pendingMedia?.itemID, "missing")
        var opened: String?
        await router.consumePendingMedia { $0.itemID } open: { opened = $0 }
        XCTAssertEqual(opened, "missing")
        XCTAssertNil(router.pendingMedia)
    }

    /// Wrong-scheme URLs round-trip as `.unknown`.
    func testRejectsWrongScheme() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/media/abc"))
        let result = FlowmarkURLRouter.parse(url)
        if case .unknown = result {} else {
            XCTFail("Expected .unknown for non-flowmark scheme")
        }
    }
}
