import os
@testable import SeerCore
import XCTest

final class ServerInfoFetcherTests: XCTestCase {
    private let baseURL = URL(string: "https://media.example.com")!

    func testFetchesLocalAddressFromSystemInfoPublic() async throws {
        let payload = Data("""
        {
          "Id": "abc-123",
          "ProductName": "Jellyfin Server",
          "ServerName": "MacMini",
          "LocalAddress": "http://192.168.1.10:8096",
          "Version": "10.8.13"
        }
        """.utf8)

        let transport = StubServerInfoTransport(response: .success(payload))
        let fetcher = ServerInfoFetcher(transport: transport)

        let info = try await fetcher.fetch(from: baseURL)

        XCTAssertEqual(info.serverID, "abc-123")
        XCTAssertEqual(info.productName, "Jellyfin Server")
        XCTAssertEqual(info.serverName, "MacMini")
        XCTAssertEqual(info.localAddress, URL(string: "http://192.168.1.10:8096"))
        XCTAssertEqual(info.version, "10.8.13")
    }

    func testRejectsNonJellyfinResponse() async {
        let payload = Data("""
        {"some": "other server"}
        """.utf8)

        let transport = StubServerInfoTransport(response: .success(payload))
        let fetcher = ServerInfoFetcher(transport: transport)

        do {
            _ = try await fetcher.fetch(from: baseURL)
            XCTFail("Expected ServerInfoError.notJellyfin")
        } catch let error as ServerInfoFetcher.ServerInfoError {
            XCTAssertEqual(error, .notJellyfin)
        } catch {
            XCTFail("Expected ServerInfoError, got \(error)")
        }
    }

    func testRejectsNonJellyfinResponseWhenProductNameDiffers() async {
        let payload = Data("""
        {
          "Id": "xyz",
          "ProductName": "Plex Media Server",
          "Version": "1.0"
        }
        """.utf8)

        let transport = StubServerInfoTransport(response: .success(payload))
        let fetcher = ServerInfoFetcher(transport: transport)

        do {
            _ = try await fetcher.fetch(from: baseURL)
            XCTFail("Expected ServerInfoError.notJellyfin")
        } catch let error as ServerInfoFetcher.ServerInfoError {
            XCTAssertEqual(error, .notJellyfin)
        } catch {
            XCTFail("Expected ServerInfoError, got \(error)")
        }
    }
}

// MARK: - Stub transport

final class StubServerInfoTransport: ServerInfoTransport {
    private let response: Result<Data, Error>

    init(response: Result<Data, Error>) {
        self.response = response
    }

    func fetchPublicInfo(from _: URL) async throws -> Data {
        try response.get()
    }
}
