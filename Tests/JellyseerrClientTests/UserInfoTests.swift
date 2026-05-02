@testable import JellyseerrClient
import XCTest

final class UserInfoTests: XCTestCase {
    // MARK: - displayName

    func testDisplayName_prefersJellyfinUsername() throws {
        let user = try makeUser(
            email: "user@example.com",
            plexUsername: "plexuser",
            jellyfinUsername: "jelly",
            username: "user"
        )
        XCTAssertEqual(user.displayName, "jelly")
    }

    func testDisplayName_fallsBackToPlexUsername() throws {
        let user = try makeUser(
            email: "user@example.com",
            plexUsername: "plexuser",
            jellyfinUsername: nil,
            username: "user"
        )
        XCTAssertEqual(user.displayName, "plexuser")
    }

    func testDisplayName_fallsBackToUsername() throws {
        let user = try makeUser(
            email: "user@example.com",
            plexUsername: nil,
            jellyfinUsername: nil,
            username: "user"
        )
        XCTAssertEqual(user.displayName, "user")
    }

    func testDisplayName_fallsBackToEmail() throws {
        let user = try makeUser(
            email: "user@example.com",
            plexUsername: nil,
            jellyfinUsername: nil,
            username: nil
        )
        XCTAssertEqual(user.displayName, "user@example.com")
    }

    func testDisplayName_allNil_returnsUser() throws {
        let user = try makeUser(
            email: nil,
            plexUsername: nil,
            jellyfinUsername: nil,
            username: nil
        )
        XCTAssertEqual(user.displayName, "User")
    }

    // MARK: - userTypeDescription

    func testUserTypeDescription_plex_returnsPlexUser() throws {
        XCTAssertEqual(try makeUser(userType: 1).userTypeDescription, "Plex User")
    }

    func testUserTypeDescription_local_returnsLocalUser() throws {
        XCTAssertEqual(try makeUser(userType: 2).userTypeDescription, "Local User")
    }

    func testUserTypeDescription_jellyfin_returnsJellyfinUser() throws {
        XCTAssertEqual(try makeUser(userType: 3).userTypeDescription, "Jellyfin User")
    }

    func testUserTypeDescription_unknownValue_returnsUnknown() throws {
        XCTAssertEqual(try makeUser(userType: 99).userTypeDescription, "Unknown")
    }

    // MARK: - Permission Helpers

    func testIsAdmin_adminPermission_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 2).isAdmin)
    }

    func testIsAdmin_nonAdmin_returnsFalse() throws {
        XCTAssertFalse(try makeUser(permissions: 32).isAdmin) // request only
    }

    func testCanManageRequests_admin_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 2).canManageRequests)
    }

    func testCanManageRequests_manageRequestsPermission_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 16).canManageRequests)
    }

    func testCanManageRequests_basicRequest_returnsFalse() throws {
        XCTAssertFalse(try makeUser(permissions: 32).canManageRequests)
    }

    func testCanRequest4K_basicUser_returnsFalse() throws {
        XCTAssertFalse(try makeUser(permissions: 32).canRequest4K)
    }

    func testCanRequest4K_request4KPermission_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 1024).canRequest4K)
    }

    func testCanUseAdvancedRequest_admin_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 2).canUseAdvancedRequest)
    }

    func testCanUseAdvancedRequest_advancedPermission_returnsTrue() throws {
        XCTAssertTrue(try makeUser(permissions: 8192).canUseAdvancedRequest)
    }

    func testCanUseAdvancedRequest_basic_returnsFalse() throws {
        XCTAssertFalse(try makeUser(permissions: 32).canUseAdvancedRequest)
    }

    // MARK: - Decoding

    func testDecode_validJSON_decodesCorrectly() throws {
        let json = """
        {
          "id": 5,
          "email": "test@example.com",
          "plexUsername": null,
          "jellyfinUsername": "jelly",
          "username": "test",
          "recoveryLinkExpirationDate": null,
          "userType": 3,
          "permissions": 16,
          "avatar": null,
          "movieQuotaLimit": 10,
          "movieQuotaDays": 7,
          "tvQuotaLimit": null,
          "tvQuotaDays": null,
          "createdAt": "2024-01-01T00:00:00.000Z",
          "updatedAt": "2024-06-01T00:00:00.000Z",
          "requestCount": 42
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(UserInfo.self, from: json)

        XCTAssertEqual(user.id, 5)
        XCTAssertEqual(user.jellyfinUsername, "jelly")
        XCTAssertEqual(user.userType, 3)
        XCTAssertEqual(user.permissions, 16)
        XCTAssertEqual(user.requestCount, 42)
        XCTAssertTrue(user.canManageRequests)
        XCTAssertEqual(user.userTypeDescription, "Jellyfin User")
        XCTAssertEqual(user.displayName, "jelly")
    }

    // MARK: - Helpers

    private func makeUser(
        id: Int = 1,
        email: String? = nil,
        plexUsername: String? = nil,
        jellyfinUsername: String? = nil,
        username: String? = nil,
        userType: Int = 3,
        permissions: Int = 0
    ) throws -> UserInfo {
        let json = """
        {
          "id": \(id),
          "email": \(email.map { "\"\($0)\"" } ?? "null"),
          "plexUsername": \(plexUsername.map { "\"\($0)\"" } ?? "null"),
          "jellyfinUsername": \(jellyfinUsername.map { "\"\($0)\"" } ?? "null"),
          "username": \(username.map { "\"\($0)\"" } ?? "null"),
          "recoveryLinkExpirationDate": null,
          "userType": \(userType),
          "permissions": \(permissions),
          "avatar": null,
          "movieQuotaLimit": null,
          "movieQuotaDays": null,
          "tvQuotaLimit": null,
          "tvQuotaDays": null,
          "createdAt": "2024-01-01T00:00:00.000Z",
          "updatedAt": "2024-01-01T00:00:00.000Z",
          "requestCount": 0
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(UserInfo.self, from: json)
    }
}
