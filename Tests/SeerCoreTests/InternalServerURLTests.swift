@testable import SeerCore
import XCTest

final class InternalServerURLTests: XCTestCase {
    func testEmptyInputClearsInternalURL() throws {
        XCTAssertNil(try InternalServerURL.parse(" \n "))
    }

    func testHTTPAddressPreservesPortAndPath() throws {
        XCTAssertEqual(
            try InternalServerURL.parse("  http://192.168.1.10:8096/jellyfin  ")?.absoluteString,
            "http://192.168.1.10:8096/jellyfin"
        )
    }

    func testHTTPSAddressIsAccepted() throws {
        XCTAssertEqual(try InternalServerURL.parse("https://server.local")?.host, "server.local")
    }

    func testUnsupportedSchemeIsRejectedWithActionableAdvice() {
        XCTAssertThrowsError(try InternalServerURL.parse("ftp://server.local")) { error in
            XCTAssertTrue(error.localizedDescription.contains("http://"))
            XCTAssertTrue(error.localizedDescription.contains("https://"))
            XCTAssertFalse(error.localizedDescription.contains("https://ftp://"))
            XCTAssertFalse(error.localizedDescription.contains("http://ftp://"))
        }
    }

    func testMissingSchemeIsRejected() {
        XCTAssertThrowsError(try InternalServerURL.parse("server.local:8096"))
    }

    func testHostlessAddressIsRejectedWithActionableAdvice() {
        XCTAssertThrowsError(try InternalServerURL.parse("https:///")) { error in
            XCTAssertTrue(error.localizedDescription.contains("host"))
        }
    }
}
