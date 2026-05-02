@testable import SeerCore
import XCTest

final class ServerConfigurationTests: XCTestCase {
    let jellyfinURL = URL(string: "https://jellyfin.example.com")!
    let jellyseerrURL = URL(string: "https://jellyseerr.example.com")!
    let internalURL = URL(string: "http://192.168.1.10:8096")!

    // MARK: - hasJellyseerr

    func testHasJellyseerr_whenURLProvided_returnsTrue() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL, jellyseerrURL: jellyseerrURL)
        XCTAssertTrue(config.hasJellyseerr)
    }

    func testHasJellyseerr_whenURLNil_returnsFalse() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL)
        XCTAssertFalse(config.hasJellyseerr)
    }

    // MARK: - hasInternalURL

    func testHasInternalURL_withURLAndSSIDs_returnsTrue() {
        let config = ServerConfiguration(
            name: "Test",
            jellyfinURL: jellyfinURL,
            internalJellyfinURL: internalURL,
            internalNetworkSSIDs: ["HomeWiFi"]
        )
        XCTAssertTrue(config.hasInternalURL)
    }

    func testHasInternalURL_withURLButNoSSIDs_returnsFalse() {
        let config = ServerConfiguration(
            name: "Test",
            jellyfinURL: jellyfinURL,
            internalJellyfinURL: internalURL,
            internalNetworkSSIDs: []
        )
        XCTAssertFalse(config.hasInternalURL)
    }

    func testHasInternalURL_withSSIDsButNoURL_returnsFalse() {
        let config = ServerConfiguration(
            name: "Test",
            jellyfinURL: jellyfinURL,
            internalJellyfinURL: nil,
            internalNetworkSSIDs: ["HomeWiFi"]
        )
        XCTAssertFalse(config.hasInternalURL)
    }

    func testHasInternalURL_neitherSet_returnsFalse() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL)
        XCTAssertFalse(config.hasInternalURL)
    }

    // MARK: - jellyfinHost

    func testJellyfinHost_returnsHost() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL)
        XCTAssertEqual(config.jellyfinHost, "jellyfin.example.com")
    }

    func testJellyfinHost_urlWithPort_returnsHostOnly() {
        let url = URL(string: "http://192.168.1.10:8096")!
        let config = ServerConfiguration(name: "Test", jellyfinURL: url)
        XCTAssertEqual(config.jellyfinHost, "192.168.1.10")
    }

    // MARK: - jellyseerrHost

    func testJellyseerrHost_whenConfigured_returnsHost() {
        let config = ServerConfiguration(
            name: "Test",
            jellyfinURL: jellyfinURL,
            jellyseerrURL: jellyseerrURL
        )
        XCTAssertEqual(config.jellyseerrHost, "jellyseerr.example.com")
    }

    func testJellyseerrHost_whenNotConfigured_returnsNil() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL)
        XCTAssertNil(config.jellyseerrHost)
    }

    // MARK: - internalJellyfinHost

    func testInternalJellyfinHost_whenConfigured_returnsHost() {
        let config = ServerConfiguration(
            name: "Test",
            jellyfinURL: jellyfinURL,
            internalJellyfinURL: internalURL
        )
        XCTAssertEqual(config.internalJellyfinHost, "192.168.1.10")
    }

    func testInternalJellyfinHost_whenNotConfigured_returnsNil() {
        let config = ServerConfiguration(name: "Test", jellyfinURL: jellyfinURL)
        XCTAssertNil(config.internalJellyfinHost)
    }

    // MARK: - ServerCredentials

    func testServerCredentials_hasJellyfinCredentials_bothSet_returnsTrue() {
        let creds = ServerCredentials(
            jellyfinAccessToken: "token",
            jellyfinDeviceID: "device-id"
        )
        XCTAssertTrue(creds.hasJellyfinCredentials)
    }

    func testServerCredentials_hasJellyfinCredentials_missingToken_returnsFalse() {
        let creds = ServerCredentials(jellyfinDeviceID: "device-id")
        XCTAssertFalse(creds.hasJellyfinCredentials)
    }

    func testServerCredentials_hasJellyfinCredentials_missingDevice_returnsFalse() {
        let creds = ServerCredentials(jellyfinAccessToken: "token")
        XCTAssertFalse(creds.hasJellyfinCredentials)
    }

    func testServerCredentials_hasJellyfinCredentials_emptyCredentials_returnsFalse() {
        let creds = ServerCredentials()
        XCTAssertFalse(creds.hasJellyfinCredentials)
    }
}
