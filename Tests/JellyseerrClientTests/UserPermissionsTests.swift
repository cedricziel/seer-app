@testable import JellyseerrClient
import XCTest

final class UserPermissionsTests: XCTestCase {
    // MARK: - canManageRequests

    func testCanManageRequests_admin_returnsTrue() {
        XCTAssertTrue(UserPermissions.admin.canManageRequests)
    }

    func testCanManageRequests_manageRequests_returnsTrue() {
        XCTAssertTrue(UserPermissions.manageRequests.canManageRequests)
    }

    func testCanManageRequests_basicUser_returnsFalse() {
        let permissions: UserPermissions = [.request, .vote]
        XCTAssertFalse(permissions.canManageRequests)
    }

    // MARK: - canRequest4K

    func testCanRequest4K_admin_returnsTrue() {
        XCTAssertTrue(UserPermissions.admin.canRequest4K)
    }

    func testCanRequest4K_request4K_returnsTrue() {
        XCTAssertTrue(UserPermissions.request4K.canRequest4K)
    }

    func testCanRequest4K_specificMovieAccess_returnsTrue() {
        XCTAssertTrue(UserPermissions.request4KMovie.canRequest4K)
    }

    func testCanRequest4K_specificTVAccess_returnsTrue() {
        XCTAssertTrue(UserPermissions.request4KTV.canRequest4K)
    }

    func testCanRequest4K_basicRequester_returnsFalse() {
        XCTAssertFalse(UserPermissions.request.canRequest4K)
    }

    // MARK: - canRequest4KMovie / canRequest4KTV

    func testCanRequest4KMovie_admin_returnsTrue() {
        XCTAssertTrue(UserPermissions.admin.canRequest4KMovie)
    }

    func testCanRequest4KMovie_onlyTV_returnsFalse() {
        XCTAssertFalse(UserPermissions.request4KTV.canRequest4KMovie)
    }

    func testCanRequest4KTV_admin_returnsTrue() {
        XCTAssertTrue(UserPermissions.admin.canRequest4KTV)
    }

    func testCanRequest4KTV_onlyMovie_returnsFalse() {
        XCTAssertFalse(UserPermissions.request4KMovie.canRequest4KTV)
    }

    // MARK: - Composition

    func testOptionSetComposition_combinesMultiplePermissions() {
        let permissions: UserPermissions = [.request, .vote, .request4K]
        XCTAssertTrue(permissions.contains(.request))
        XCTAssertTrue(permissions.contains(.vote))
        XCTAssertTrue(permissions.contains(.request4K))
        XCTAssertFalse(permissions.contains(.admin))
    }

    func testRawValueArithmetic_decodesCorrectly() {
        // Mix admin (2) + manageRequests (16) = 18
        let permissions = UserPermissions(rawValue: 18)
        XCTAssertTrue(permissions.contains(.admin))
        XCTAssertTrue(permissions.contains(.manageRequests))
        XCTAssertFalse(permissions.contains(.request))
    }
}
