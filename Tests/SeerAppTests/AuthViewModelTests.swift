@testable import SeerApp
@testable import SeerCore
import XCTest

/// End-to-end tests covering the auth view model's user-visible behavior:
/// - Validation runs before any network call
/// - Errors surface both a primary message and a suggestion
/// - Clearing the error wipes both fields
@MainActor
final class AuthViewModelTests: XCTestCase {
    private var appState: AppState!
    private var viewModel: AuthViewModel!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        viewModel = AuthViewModel(appState: appState)
    }

    override func tearDown() async throws {
        viewModel = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - URL validation surfaces specific suggestions

    func testConnectToJellyfin_emptyURL_showsExampleSuggestion() async {
        viewModel.jellyfinServerURL = ""
        viewModel.jellyfinUsername = "user"

        await viewModel.connectToJellyfin()

        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a server URL")
        XCTAssertTrue(viewModel.errorSuggestion?.contains("https://") ?? false)
        XCTAssertFalse(viewModel.jellyfinConnected)
    }

    func testConnectToJellyfin_missingScheme_suggestsHTTPSPrefix() async {
        viewModel.jellyfinServerURL = "jellyfin.example.com"
        viewModel.jellyfinUsername = "user"

        await viewModel.connectToJellyfin()

        XCTAssertEqual(viewModel.errorMessage, "Missing http:// or https:// prefix")
        XCTAssertTrue(viewModel.errorSuggestion?.contains("https://jellyfin.example.com") ?? false)
    }

    func testConnectToJellyfin_localIPMissingScheme_returnsAdvice() async {
        viewModel.jellyfinServerURL = "192.168.1.10:8096"
        viewModel.jellyfinUsername = "user"

        await viewModel.connectToJellyfin()

        XCTAssertEqual(viewModel.errorMessage, "Missing http:// or https:// prefix")
        XCTAssertNotNil(viewModel.errorSuggestion)
    }

    func testConnectToJellyfin_validURL_butEmptyUsername_warnsAboutUsername() async {
        viewModel.jellyfinServerURL = "https://jellyfin.example.com"
        viewModel.jellyfinUsername = ""

        await viewModel.connectToJellyfin()

        XCTAssertEqual(viewModel.errorMessage, "Please enter your username")
    }

    // MARK: - Jellyseerr URL validation

    func testConnectToJellyseerr_missingScheme_returnsAdvice() async {
        viewModel.jellyseerrServerURL = "requests.example.com"
        viewModel.jellyseerrAPIKey = "abc"

        await viewModel.connectToJellyseerr()

        XCTAssertEqual(viewModel.errorMessage, "Missing http:// or https:// prefix")
        XCTAssertNotNil(viewModel.errorSuggestion)
    }

    // MARK: - clearError wipes both fields

    func testClearError_resetsMessageAndSuggestion() async {
        viewModel.jellyfinServerURL = ""
        viewModel.jellyfinUsername = "user"
        await viewModel.connectToJellyfin()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.errorSuggestion)

        viewModel.clearError()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.errorSuggestion)
        XCTAssertFalse(viewModel.showError)
    }
}
