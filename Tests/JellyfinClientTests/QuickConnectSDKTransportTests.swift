import Foundation
@testable import JellyfinClient
import XCTest

@MainActor
final class QuickConnectSDKTransportTests: XCTestCase {
    func testGeneratedQuickConnectFlowKeepsSecretDeviceAndProxyPath() async throws {
        let server = SDKStubServer(status: 200, body: "true")
        server.enqueue(status: 200, body: #"{"Code":"ABC123","Secret":"a+b /?"}"#)
        server.enqueue(status: 200, body: #"{"Authenticated":false}"#)
        server.enqueue(
            status: 200,
            body: #"{"User":{"Id":"user-1","Name":"Jelly"},"AccessToken":"TOKEN-1","ServerId":"server-1"}"#
        )
        let session = URLSession(configuration: server.configuration)
        defer { session.invalidateAndCancel() }
        let transport = URLSessionQuickConnectTransport(session: session, deviceID: "quick-device")

        let enabled = try await transport.isEnabled(serverURL: server.url)
        let initiate = try await transport.initiate(serverURL: server.url)
        let state = try await transport.pollState(serverURL: server.url, secret: initiate.secret)
        let auth = try await transport.authenticate(serverURL: server.url, secret: initiate.secret)

        XCTAssertTrue(enabled)
        XCTAssertEqual(initiate.code, "ABC123")
        XCTAssertFalse(state.authenticated)
        XCTAssertEqual(auth.accessToken, "TOKEN-1")
        XCTAssertEqual(server.requests.map(\.httpMethod), ["GET", "POST", "GET", "POST"])
        XCTAssertEqual(server.requests.map { $0.url?.path }, [
            "/jellyfin/QuickConnect/Enabled", "/jellyfin/QuickConnect/Initiate",
            "/jellyfin/QuickConnect/Connect", "/jellyfin/Users/AuthenticateWithQuickConnect"
        ])
        let pollURL = try XCTUnwrap(server.requests[2].url)
        XCTAssertEqual(
            URLComponents(url: pollURL, resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "secret", value: "a+b /?")]
        )
        let encodedQuery = try XCTUnwrap(URLComponents(url: pollURL, resolvingAgainstBaseURL: false)?
            .percentEncodedQuery)
        XCTAssertTrue(encodedQuery.contains("secret=a%2Bb"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: server.bodies[3]) as? [String: String])
        XCTAssertEqual(body, ["Secret": "a+b /?"])
        let authorization = try XCTUnwrap(server.requests[3].value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(authorization.contains("DeviceId=quick-device"))
        XCTAssertFalse(authorization.contains("Token="))
    }

    func testUnavailableQuickConnectRetainsPasswordFallback() async throws {
        let server = SDKStubServer(status: 404, body: "Not available")
        let session = URLSession(configuration: server.configuration)
        defer { session.invalidateAndCancel() }
        let transport = URLSessionQuickConnectTransport(session: session, deviceID: "quick-device")

        let enabled = try await transport.isEnabled(serverURL: server.url)

        XCTAssertFalse(enabled)
    }
}
