@testable import PlaybackClient
import XCTest

final class PlaybackFailureMessageTests: XCTestCase {
    func testAuthenticationFailureGivesSignInGuidance() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired)
        XCTAssertTrue(PlaybackFailureMessage.message(for: error).contains("sign in"))
    }

    func testWrappedAuthenticationFailureGivesSignInGuidance() {
        let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired)
        let error = NSError(
            domain: "AVFoundationErrorDomain",
            code: -11800,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        XCTAssertTrue(PlaybackFailureMessage.message(for: error).contains("sign in"))
    }

    func testNetworkFailureGivesConnectionAndRetryGuidance() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = PlaybackFailureMessage.message(for: error)
        XCTAssertTrue(message.contains("network connection"))
        XCTAssertTrue(message.contains("retry"))
    }

    func testServiceNetworkFailureGivesConnectionGuidance() {
        let error = PlaybackService.PlaybackError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(PlaybackFailureMessage.message(for: error).contains("network connection"))
    }

    func testUnauthorizedServiceResponseGivesSignInGuidance() {
        let error = PlaybackService.PlaybackError.serverError(401, "private server response")
        XCTAssertTrue(PlaybackFailureMessage.message(for: error).contains("sign in"))
        XCTAssertFalse(PlaybackFailureMessage.message(for: error).contains("private server response"))
    }

    func testForbiddenServiceResponseGivesPermissionGuidance() {
        let error = PlaybackService.PlaybackError.serverError(403, "private server response")
        XCTAssertTrue(PlaybackFailureMessage.message(for: error).contains("account permissions"))
    }

    func testUnknownFailureDoesNotExposeServerDetails() {
        let error = NSError(
            domain: "PrivateServer",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "https://private.invalid/?api_key=secret"]
        )
        let message = PlaybackFailureMessage.message(for: error)
        XCTAssertFalse(message.contains("private.invalid"))
        XCTAssertFalse(message.contains("secret"))
        XCTAssertTrue(message.contains("transcoding settings"))
    }

    func testMissingErrorGivesRecoveryGuidance() {
        XCTAssertTrue(PlaybackFailureMessage.message(for: nil).contains("Retry"))
    }
}
