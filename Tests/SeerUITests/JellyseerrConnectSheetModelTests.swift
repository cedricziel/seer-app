import os
@testable import SeerUI
import XCTest

@MainActor
final class JellyseerrConnectSheetModelTests: XCTestCase {
    func testValidatesCredentialsBeforeDismiss() async {
        let connector = RecordingConnector(
            response: .failure(FakeAuthError.unauthorized)
        )
        let model = JellyseerrConnectSheetModel(connector: connector.callAsFunction)
        model.url = "https://jellyseerr.example.com"
        model.apiKey = "bad-key"

        let success = await model.attemptConnect()

        XCTAssertFalse(success)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(connector.callCount, 1)
    }

    func testPersistsCredentialsOnSuccess() async {
        let connector = RecordingConnector(response: .success(()))
        let model = JellyseerrConnectSheetModel(connector: connector.callAsFunction)
        model.url = "https://jellyseerr.example.com"
        model.apiKey = "good-key"

        let success = await model.attemptConnect()

        XCTAssertTrue(success)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(connector.callCount, 1)
        XCTAssertEqual(connector.lastURL, URL(string: "https://jellyseerr.example.com"))
        XCTAssertEqual(connector.lastAPIKey, "good-key")
    }

    func testCancelDoesNotPersist() {
        // The sheet's cancel path is purely UI; this asserts that the model
        // by itself does not invoke the connector when attemptConnect is
        // never called (i.e. the user dismisses without tapping Connect).
        let connector = RecordingConnector(response: .success(()))
        let model = JellyseerrConnectSheetModel(connector: connector.callAsFunction)
        model.url = "https://jellyseerr.example.com"
        model.apiKey = "good-key"

        // No attemptConnect() call.

        XCTAssertEqual(connector.callCount, 0)
    }

    func testRejectsInvalidURL() async {
        let connector = RecordingConnector(response: .success(()))
        let model = JellyseerrConnectSheetModel(connector: connector.callAsFunction)
        model.url = "not a url"
        model.apiKey = "key"

        let success = await model.attemptConnect()

        XCTAssertFalse(success)
        XCTAssertEqual(connector.callCount, 0)
        XCTAssertNotNil(model.errorMessage)
    }

    func testRejectsEmptyAPIKey() async {
        let connector = RecordingConnector(response: .success(()))
        let model = JellyseerrConnectSheetModel(connector: connector.callAsFunction)
        model.url = "https://jellyseerr.example.com"
        model.apiKey = "   "

        let success = await model.attemptConnect()

        XCTAssertFalse(success)
        XCTAssertEqual(connector.callCount, 0)
    }

    func testIsSubmittableRequiresBothFields() {
        let model = JellyseerrConnectSheetModel(connector: { _, _ in })

        XCTAssertFalse(model.isSubmittable)
        model.url = "https://x"
        XCTAssertFalse(model.isSubmittable)
        model.apiKey = "k"
        XCTAssertTrue(model.isSubmittable)
    }
}

// MARK: - Helpers

@MainActor
final class RecordingConnector {
    private struct State {
        var callCount = 0
        var lastURL: URL?
        var lastAPIKey: String?
    }

    private let response: Result<Void, Error>
    private var state = State()

    var callCount: Int {
        state.callCount
    }

    var lastURL: URL? {
        state.lastURL
    }

    var lastAPIKey: String? {
        state.lastAPIKey
    }

    init(response: Result<Void, Error>) {
        self.response = response
    }

    @MainActor
    @Sendable
    func callAsFunction(_ url: URL, _ apiKey: String) async throws {
        state.callCount += 1
        state.lastURL = url
        state.lastAPIKey = apiKey
        try response.get()
    }
}

enum FakeAuthError: LocalizedError {
    case unauthorized
    var errorDescription: String? {
        "Authentication failed"
    }
}
