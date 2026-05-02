@testable import SeerCore
import XCTest

final class WelcomeStateResolverTests: XCTestCase {
    private let resolver = WelcomeStateResolver()

    func testFreshInstallShowsManualEntryAsPrimary() {
        let state = resolver.resolve(synced: [], bonjour: [])

        XCTAssertEqual(state.primary, .manualEntry)
        XCTAssertTrue(state.secondary.isEmpty)
        XCTAssertFalse(state.hasSuggestions)
    }

    func testSyncedServerTakesPrecedenceOverBonjour() {
        let synced = WelcomeSuggestion(
            id: "synced-1",
            title: "MacMini",
            subtitle: "macmini.local",
            source: .synced,
            symbolName: "icloud.fill"
        )
        let bonjour = WelcomeSuggestion(
            id: "bonjour-1",
            title: "OtherHost",
            subtitle: "otherhost.local",
            source: .bonjour,
            symbolName: "wifi"
        )

        let state = resolver.resolve(synced: [synced], bonjour: [bonjour])

        XCTAssertEqual(state.primary, .suggestion(synced))
        XCTAssertEqual(state.secondary, [bonjour])
        XCTAssertTrue(state.hasSuggestions)
    }

    func testBonjourSuggestionAppearsWhenNoSynced() {
        let bonjour = WelcomeSuggestion(
            id: "bonjour-1",
            title: "MacMini",
            subtitle: "macmini.local",
            source: .bonjour,
            symbolName: "wifi"
        )

        let state = resolver.resolve(synced: [], bonjour: [bonjour])

        XCTAssertEqual(state.primary, .suggestion(bonjour))
        XCTAssertTrue(state.secondary.isEmpty)
    }

    func testMultipleSyncedSurfaceAsSecondary() {
        let first = WelcomeSuggestion(
            id: "s1", title: "S1", subtitle: "s1", source: .synced, symbolName: "icloud.fill"
        )
        let second = WelcomeSuggestion(
            id: "s2", title: "S2", subtitle: "s2", source: .synced, symbolName: "icloud.fill"
        )
        let bonjour = WelcomeSuggestion(
            id: "b1", title: "B1", subtitle: "b1", source: .bonjour, symbolName: "wifi"
        )

        let state = resolver.resolve(synced: [first, second], bonjour: [bonjour])

        XCTAssertEqual(state.primary, .suggestion(first))
        XCTAssertEqual(state.secondary, [second, bonjour])
    }
}
