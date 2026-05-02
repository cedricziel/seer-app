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
        XCTAssertEqual(router.pendingMediaID, "abc-123")
        XCTAssertEqual(router.selectedTab, .library)
    }

    /// 6.8 — flowmark://library opens the Library tab.
    func testRoutesLibraryURLToLibraryTab() throws {
        let router = FlowmarkURLRouter()
        let url = try XCTUnwrap(URL(string: "flowmark://library"))
        let result = router.route(url)

        XCTAssertEqual(result, .openLibrary)
        XCTAssertNil(router.pendingMediaID)
        XCTAssertEqual(router.selectedTab, .library)
    }

    /// 6.9 — Unknown path is a no-op (does not throw, does not change state).
    func testIgnoresUnknownPath() throws {
        let router = FlowmarkURLRouter()
        router.selectedTab = .discover
        router.pendingMediaID = "preserved"

        let url = try XCTUnwrap(URL(string: "flowmark://requests/42"))
        let result = router.route(url)

        if case .unknown = result {} else {
            XCTFail("Expected .unknown, got \(result)")
        }
        XCTAssertEqual(router.selectedTab, .discover)
        XCTAssertEqual(router.pendingMediaID, "preserved")
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
