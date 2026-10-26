import Foundation
@testable import JellyfinClient
import XCTest

@MainActor
final class JellyfinServiceSDKTests: XCTestCase {
    func testInjectedSessionConfigurationSurvivesAuthenticationAndCredentialRefresh() async throws {
        let server = SDKStubServer(status: 200, body: #"{"Items":[]}"#)
        server.enqueue(
            status: 200,
            body: #"{"User":{"Id":"new-user","Name":"Jelly"},"AccessToken":"new-token","ServerId":"server"}"#
        )
        server.enqueue(status: 200, body: #"{"Items":[]}"#)
        server.enqueue(status: 200, body: #"{"Items":[]}"#)
        let configuration = server.configuration
        configuration.timeoutIntervalForRequest = 17
        configuration.timeoutIntervalForResource = 29
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = JellyfinService(
            serverURL: server.url,
            accessToken: "old-token",
            userID: "old-user",
            deviceID: "session-device",
            session: session
        )

        _ = try await service.getLibraries()
        _ = try await service.authenticate(username: "Jelly", password: "secret")
        _ = try await service.getLibraries()
        await service.setCredentials(accessToken: "restored-token", userID: "restored-user")
        _ = try await service.getLibraries()

        XCTAssertEqual(server.requests.count, 4)
        XCTAssertFalse(try XCTUnwrap(server.requests[1].value(forHTTPHeaderField: "Authorization")).contains("Token="))
        XCTAssertTrue(try XCTUnwrap(server.requests[2].value(forHTTPHeaderField: "Authorization"))
            .contains("Token=new-token"))
        XCTAssertTrue(try XCTUnwrap(server.requests[3].value(forHTTPHeaderField: "Authorization"))
            .contains("Token=restored-token"))
        XCTAssertEqual(query(server.requests[3])["userId"], "restored-user")
    }

    func testAuthenticationDoesNotSendAnExistingTokenAndRestoresNewCredentials() async throws {
        let server = SDKStubServer(
            status: 200,
            body: #"""
            {
              "User": {
                "Id": "new-user",
                "Name": "Jelly"
              },
              "AccessToken": "new-token",
              "ServerId": "server"
            }
            """#
        )
        server.enqueue(status: 200, body: #"""
        {
          "Items": []
        }
        """#)
        let service = server.service(token: "old-token", userID: "old-user")

        let auth = try await service.authenticate(username: "Jelly", password: "secret")
        _ = try await service.getLibraries()

        XCTAssertEqual(auth.user.id, "new-user")
        XCTAssertFalse(try XCTUnwrap(server.requests[0].value(forHTTPHeaderField: "Authorization")).contains("Token="))
        XCTAssertEqual(server.requests[0].url?.path, "/jellyfin/Users/AuthenticateByName")
        XCTAssertEqual(server.requests[1].url?.path, "/jellyfin/UserViews")
        XCTAssertTrue(try XCTUnwrap(server.requests[1].value(forHTTPHeaderField: "Authorization"))
            .contains("Token=new-token"))
        XCTAssertEqual(query(server.requests[1])["userId"], "new-user")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: server.bodies[0]) as? [String: String])
        XCTAssertEqual(body, ["Username": "Jelly", "Pw": "secret"])
    }

    func testAuthenticationFailureRetainsInvalidCredentialsError() async throws {
        let server = SDKStubServer(status: 401, body: "Invalid password")
        do {
            _ = try await server.service().authenticate(username: "Jelly", password: "wrong")
            XCTFail("Expected invalid credentials")
        } catch JellyfinService.JellyfinError.invalidCredentials {}
    }

    func testFailedReauthenticationKeepsThePreviousSession() async throws {
        let server = SDKStubServer(status: 401, body: "Invalid password")
        server.enqueue(status: 200, body: #"{"Items":[]}"#)
        let service = server.service(token: "existing-token", userID: "existing-user")
        do {
            _ = try await service.authenticate(username: "Jelly", password: "wrong")
            XCTFail("Expected invalid credentials")
        } catch JellyfinService.JellyfinError.invalidCredentials {}

        _ = try await service.getLibraries()

        XCTAssertTrue(try XCTUnwrap(server.requests[1].value(forHTTPHeaderField: "Authorization"))
            .contains("Token=existing-token"))
        XCTAssertEqual(query(server.requests[1])["userId"], "existing-user")
    }

    func testServerFailureRetainsStatusAndResponseBody() async throws {
        let server = SDKStubServer(status: 403, body: "Library access denied")
        do {
            _ = try await server.service().getLibraries()
            XCTFail("Expected server failure")
        } catch let JellyfinService.JellyfinError.serverError(status, body) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(body, "Library access denied")
        }
    }

    func testItemsKeepSearchPaginationAndAppModelDecoding() async throws {
        let server = SDKStubServer(
            status: 200,
            body: #"""
            {
              "Items": [
                {
                  "Id": "00000000-0000-0000-0000-000000000001",
                  "Name": "Future",
                  "Type": "FutureMediaKind",
                  "CommunityRating": null
                }
              ],
              "TotalRecordCount": 43,
              "StartIndex": 40
            }
            """#
        )

        let response = try await server.service().getItems(
            parentID: "library-1",
            includeItemTypes: [.movie, .series],
            sortBy: "PremiereDate,SortName",
            sortOrder: "Descending",
            limit: 20,
            startIndex: 40,
            searchTerm: "a+b & c"
        )

        let request = try XCTUnwrap(server.requests.first)
        XCTAssertEqual(request.url?.path, "/jellyfin/Items")
        XCTAssertEqual(query(request)["searchTerm"], "a+b & c")
        XCTAssertEqual(query(request)["parentId"], "library-1")
        XCTAssertEqual(query(request)["userId"], "user-1")
        XCTAssertEqual(query(request)["startIndex"], "40")
        XCTAssertEqual(query(request)["limit"], "20")
        XCTAssertEqual(queryValues(request, name: "sortBy"), ["PremiereDate", "SortName"])
        XCTAssertEqual(query(request)["sortOrder"], "Descending")
        XCTAssertEqual(queryValues(request, name: "includeItemTypes"), ["Movie", "Series"])
        XCTAssertEqual(response.totalRecordCount, 43)
        XCTAssertEqual(response.startIndex, 40)
        XCTAssertEqual(response.items.first?.id, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(response.items.first?.type, .unknown)
        XCTAssertNil(response.items.first?.communityRating)
    }

    func testEveryLibrarySortAndFilterValueIsRepresentedByTheSDK() async throws {
        let server = SDKStubServer(status: 200, body: #"{"Items":[],"TotalRecordCount":0,"StartIndex":0}"#)

        _ = try await server.service().getItems(
            sortBy: "DateCreated,ProductionYear,CommunityRating,SortName,IndexNumber,PremiereDate",
            filters: ["IsUnplayed", "IsFavorite"]
        )

        let request = try XCTUnwrap(server.requests.first)
        XCTAssertEqual(queryValues(request, name: "sortBy"), [
            "DateCreated", "ProductionYear", "CommunityRating", "SortName", "IndexNumber", "PremiereDate"
        ])
        XCTAssertEqual(queryValues(request, name: "filters"), ["IsUnplayed", "IsFavorite"])
    }

    func testItemDecodesFractionalDatesAndMediaSourceFieldsWithoutSDKModelLoss() async throws {
        let server = SDKStubServer(
            status: 200,
            body: #"""
            {
              "Id": "item-1",
              "Name": "Film",
              "Type": "Movie",
              "PremiereDate": "2026-01-01T12:00:00.1234567Z",
              "MediaSources": [
                {
                  "Container": "mkv",
                  "Size": 1024,
                  "MediaStreams": [
                    {
                      "Type": "Video",
                      "Codec": "hevc",
                      "Width": 3840,
                      "Height": 2160
                    }
                  ]
                }
              ]
            }
            """#
        )

        let item = try await server.service().getItem(id: "item-1")

        XCTAssertEqual(item.id, "item-1")
        XCTAssertNotNil(item.premiereDate)
        XCTAssertEqual(item.container, "mkv")
        XCTAssertEqual(item.videoCodec, "hevc")
        XCTAssertEqual(item.fileSizeBytes, 1024)
        XCTAssertEqual(server.requests.first?.url?.path, "/jellyfin/Items/item-1")
        XCTAssertNil(try query(XCTUnwrap(server.requests.first))["Fields"])
    }

    func testCredentialRestorationChangesTokenAndUserWithoutChangingDeviceIdentity() async throws {
        let server = SDKStubServer(status: 200, body: #"""
        {
          "Items": []
        }
        """#)
        let service = server.service()
        _ = try await service.getLibraries()

        await service.setCredentials(accessToken: "restored-token", userID: "restored-user")
        _ = try await service.getLibraries()

        XCTAssertTrue(try XCTUnwrap(server.requests[0].value(forHTTPHeaderField: "Authorization"))
            .contains("DeviceId=device-1"))
        XCTAssertTrue(try XCTUnwrap(server.requests[1].value(forHTTPHeaderField: "Authorization"))
            .contains("DeviceId=device-1"))
        XCTAssertTrue(try XCTUnwrap(server.requests[1].value(forHTTPHeaderField: "Authorization"))
            .contains("Token=restored-token"))
        XCTAssertEqual(query(server.requests[1])["userId"], "restored-user")
    }

    func testMutationsUseGeneratedUserRoutesAndKeepTickPrecision() async throws {
        let server = SDKStubServer(status: 204, body: "")
        let service = server.service()

        try await service.setFavorite(itemId: "item-1", isFavorite: true)
        try await service.setFavorite(itemId: "item-1", isFavorite: false)
        try await service.markAsPlayed(itemId: "item-1")
        try await service.markAsUnplayed(itemId: "item-1")
        try await service.reportPlaybackProgress(itemId: "item-1", positionTicks: 9_007_199_254_740_993, isPaused: true)

        XCTAssertEqual(server.requests.map(\.httpMethod), ["POST", "DELETE", "POST", "DELETE", "POST"])
        XCTAssertEqual(server.requests.map { $0.url?.path }, [
            "/jellyfin/UserFavoriteItems/item-1", "/jellyfin/UserFavoriteItems/item-1",
            "/jellyfin/UserPlayedItems/item-1", "/jellyfin/UserPlayedItems/item-1",
            "/jellyfin/Sessions/Playing/Progress"
        ])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: server.bodies[4]) as? [String: Any])
        XCTAssertEqual((body["PositionTicks"] as? NSNumber)?.int64Value, 9_007_199_254_740_993)
        XCTAssertEqual(body["IsPaused"] as? Bool, true)
        XCTAssertEqual(Set(body.keys), ["ItemId", "PositionTicks", "IsPaused", "PlaySessionId"])
    }

    private func queryValues(_ request: URLRequest, name: String) -> [String] {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [] }
        return items.filter { $0.name == name }.compactMap(\.value).flatMap { $0.components(separatedBy: ",") }
    }

    private func query(_ request: URLRequest) -> [String: String] {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }
}
