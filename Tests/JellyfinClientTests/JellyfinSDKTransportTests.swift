import Foundation
@testable import JellyfinClient
import XCTest

@MainActor
final class JellyfinSDKTransportTests: XCTestCase {
    func testGeneratedRequestPreservesProxyPathQueryAndCredentials() async throws {
        let server = SDKStubServer(status: 200, body: #"""
        {
          "Items": []
        }
        """#)
        _ = try await server.service().getLibraries()

        let request = try XCTUnwrap(server.requests.first)
        XCTAssertEqual(request.url?.path, "/jellyfin/UserViews")
        XCTAssertEqual(
            try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "userId", value: "user-1")]
        )
        let authorization = try XCTUnwrap(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(authorization.contains("DeviceId=device-1"))
        XCTAssertTrue(authorization.contains("Client=Seer"))
        XCTAssertTrue(authorization.contains("Token=TOKEN-1"))
    }

    func testGeneratedSearchEscapesLiteralPlusWithoutChangingBaseQueryEncoding() async throws {
        let server = SDKStubServer(
            status: 200,
            body: #"{"Items":[],"TotalRecordCount":0,"StartIndex":0}"#,
            baseQuery: "proxy=a+b&encoded=a%2Bb"
        )

        _ = try await server.service().search(query: "C++")

        let url = try XCTUnwrap(server.requests.first?.url)
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        XCTAssertTrue(query.hasPrefix("proxy=a+b&encoded=a%2Bb&"))
        XCTAssertEqual(query.split(separator: "&").filter { $0.hasPrefix("searchTerm=") }, ["searchTerm=C%2B%2B"])
    }

    func testFailureKeepsStatusAndBodyForDomainErrorMapping() async throws {
        let server = SDKStubServer(status: 401, body: "Session expired")

        let (data, response) = try await server.transport(token: "expired").playbackInfo(
            itemID: "item-1",
            body: [String: String]()
        )

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Session expired")
    }

    func testRawResponseDoesNotLoseUnknownMediaFieldsOrIdentifierFormatting() async throws {
        let payload = #"""
        {
          "Items": [
            {
              "Id": "00000000-0000-0000-0000-000000000001",
              "Type": "FutureMediaKind",
              "FutureField": true
            }
          ]
        }
        """#
        let server = SDKStubServer(status: 200, body: payload)

        let (data, _) = try await server.transport().playbackInfo(itemID: "item-1", body: [String: String]())

        XCTAssertEqual(data, Data(payload.utf8))
    }
}
