@testable import SeerCore
import XCTest

final class AuthErrorFormatterTests: XCTestCase {
    // MARK: - URL Validation

    func testValidate_emptyURL_returnsAdviceWithExample() {
        let advice = AuthErrorFormatter.validate(urlString: "")
        XCTAssertNotNil(advice)
        XCTAssertEqual(advice?.message, "Please enter a server URL")
        XCTAssertNotNil(advice?.suggestion)
        XCTAssertTrue(advice?.suggestion?.contains("https://") ?? false)
    }

    func testValidate_whitespaceOnly_treatedAsEmpty() {
        let advice = AuthErrorFormatter.validate(urlString: "    ")
        XCTAssertEqual(advice?.message, "Please enter a server URL")
    }

    func testValidate_missingScheme_suggestsHTTPS() {
        let advice = AuthErrorFormatter.validate(urlString: "jellyfin.example.com")
        XCTAssertNotNil(advice)
        XCTAssertEqual(advice?.message, "Missing http:// or https:// prefix")
        XCTAssertTrue(advice?.suggestion?.contains("https://jellyfin.example.com") ?? false)
        XCTAssertTrue(advice?.suggestion?.contains("http://jellyfin.example.com") ?? false)
    }

    func testValidate_localIPWithoutScheme_suggestsBothSchemes() {
        let advice = AuthErrorFormatter.validate(urlString: "192.168.1.10:8096")
        XCTAssertNotNil(advice)
        XCTAssertEqual(advice?.message, "Missing http:// or https:// prefix")
    }

    func testValidate_unsupportedScheme_returnsAdvice() {
        let advice = AuthErrorFormatter.validate(urlString: "ftp://jellyfin.example.com")
        XCTAssertEqual(advice?.message, "Missing http:// or https:// prefix")
    }

    func testValidate_validHTTPS_returnsNil() {
        XCTAssertNil(AuthErrorFormatter.validate(urlString: "https://jellyfin.example.com"))
    }

    func testValidate_validHTTPWithPort_returnsNil() {
        XCTAssertNil(AuthErrorFormatter.validate(urlString: "http://192.168.1.10:8096"))
    }

    func testValidate_uppercaseScheme_returnsNil() {
        XCTAssertNil(AuthErrorFormatter.validate(urlString: "HTTPS://jellyfin.example.com"))
    }

    // MARK: - URLError Mapping

    func testAdvice_cannotFindHost_suggestsTypos() {
        let error = URLError(.cannotFindHost)
        let advice = AuthErrorFormatter.advice(for: error)
        XCTAssertEqual(advice.message, "Couldn't find that server")
        XCTAssertTrue(advice.suggestion?.contains("typo") ?? false)
    }

    func testAdvice_cannotConnectToHost_localIPSuggestsPort() {
        let error = URLError(.cannotConnectToHost)
        let advice = AuthErrorFormatter.advice(for: error, urlString: "http://192.168.1.10")
        XCTAssertEqual(advice.message, "Can't reach the server")
        XCTAssertTrue(advice.suggestion?.contains("8096") ?? false)
        XCTAssertTrue(advice.suggestion?.contains("192.168.1.10") ?? false)
    }

    func testAdvice_cannotConnectToHost_localhostSuggestsPort() {
        let error = URLError(.cannotConnectToHost)
        let advice = AuthErrorFormatter.advice(for: error, urlString: "http://localhost")
        XCTAssertTrue(advice.suggestion?.contains("8096") ?? false)
    }

    func testAdvice_cannotConnectToHost_publicHostSkipsPortHint() {
        let error = URLError(.cannotConnectToHost)
        let advice = AuthErrorFormatter.advice(for: error, urlString: "https://jellyfin.example.com")
        XCTAssertEqual(advice.message, "Can't reach the server")
        XCTAssertFalse(advice.suggestion?.contains("8096") ?? true)
    }

    func testAdvice_cannotConnectToHost_withExplicitPortSkipsPortHint() {
        let error = URLError(.cannotConnectToHost)
        let advice = AuthErrorFormatter.advice(for: error, urlString: "http://192.168.1.10:7777")
        XCTAssertEqual(advice.message, "Can't reach the server")
        XCTAssertFalse(advice.suggestion?.contains(":8096") ?? true)
    }

    func testAdvice_timedOut_returnsTimeoutAdvice() {
        let advice = AuthErrorFormatter.advice(for: URLError(.timedOut))
        XCTAssertEqual(advice.message, "Connection timed out")
        XCTAssertNotNil(advice.suggestion)
    }

    func testAdvice_secureConnectionFailed_suggestsHTTP() {
        let advice = AuthErrorFormatter.advice(for: URLError(.secureConnectionFailed))
        XCTAssertEqual(advice.message, "Couldn't establish a secure connection")
        XCTAssertTrue(advice.suggestion?.contains("http://") ?? false)
    }

    func testAdvice_serverCertificateUntrusted_suggestsHTTP() {
        let advice = AuthErrorFormatter.advice(for: URLError(.serverCertificateUntrusted))
        XCTAssertEqual(advice.message, "Couldn't establish a secure connection")
    }

    func testAdvice_appTransportSecurity_suggestsHTTPS() {
        let advice = AuthErrorFormatter.advice(for: URLError(.appTransportSecurityRequiresSecureConnection))
        XCTAssertTrue(advice.suggestion?.contains("https") ?? false)
    }

    func testAdvice_notConnectedToInternet_returnsNetworkAdvice() {
        let advice = AuthErrorFormatter.advice(for: URLError(.notConnectedToInternet))
        XCTAssertEqual(advice.message, "No internet connection")
    }

    func testAdvice_userAuthRequired_suggestsCredentials() {
        let advice = AuthErrorFormatter.advice(for: URLError(.userAuthenticationRequired))
        XCTAssertEqual(advice.message, "The server rejected the credentials")
    }

    func testAdvice_unknownError_fallsBackToLocalizedDescription() {
        struct CustomError: LocalizedError {
            var errorDescription: String? {
                "Something specific went wrong"
            }
        }
        let advice = AuthErrorFormatter.advice(for: CustomError())
        XCTAssertEqual(advice.message, "Something specific went wrong")
        XCTAssertNil(advice.suggestion)
    }
}
