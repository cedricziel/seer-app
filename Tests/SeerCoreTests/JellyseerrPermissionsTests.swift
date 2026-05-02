@testable import SeerCore
import XCTest

final class JellyseerrPermissionsTests: XCTestCase {
    // MARK: - canManageRequests

    func testCanManageRequests_admin_returnsTrue() {
        let permissions = JellyseerrPermissions.admin
        XCTAssertTrue(permissions.canManageRequests)
    }

    func testCanManageRequests_manageRequests_returnsTrue() {
        let permissions = JellyseerrPermissions.manageRequests
        XCTAssertTrue(permissions.canManageRequests)
    }

    func testCanManageRequests_basicUser_returnsFalse() {
        let permissions: JellyseerrPermissions = [.request, .vote]
        XCTAssertFalse(permissions.canManageRequests)
    }

    func testCanManageRequests_emptyPermissions_returnsFalse() {
        let permissions = JellyseerrPermissions(rawValue: 0)
        XCTAssertFalse(permissions.canManageRequests)
    }

    // MARK: - canRequest4K

    func testCanRequest4K_admin_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.admin.canRequest4K)
    }

    func testCanRequest4K_request4KGeneric_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4K.canRequest4K)
    }

    func testCanRequest4K_request4KMovie_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4KMovie.canRequest4K)
    }

    func testCanRequest4K_request4KTV_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4KTV.canRequest4K)
    }

    func testCanRequest4K_basicRequester_returnsFalse() {
        XCTAssertFalse(JellyseerrPermissions.request.canRequest4K)
    }

    // MARK: - canRequest4KMovie

    func testCanRequest4KMovie_admin_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.admin.canRequest4KMovie)
    }

    func testCanRequest4KMovie_request4KGeneric_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4K.canRequest4KMovie)
    }

    func testCanRequest4KMovie_request4KMovie_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4KMovie.canRequest4KMovie)
    }

    func testCanRequest4KMovie_onlyTVAccess_returnsFalse() {
        // Specific TV permission should not grant movie access
        XCTAssertFalse(JellyseerrPermissions.request4KTV.canRequest4KMovie)
    }

    // MARK: - canRequest4KTV

    func testCanRequest4KTV_admin_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.admin.canRequest4KTV)
    }

    func testCanRequest4KTV_onlyMovieAccess_returnsFalse() {
        XCTAssertFalse(JellyseerrPermissions.request4KMovie.canRequest4KTV)
    }

    func testCanRequest4KTV_request4KTV_returnsTrue() {
        XCTAssertTrue(JellyseerrPermissions.request4KTV.canRequest4KTV)
    }

    // MARK: - OptionSet Composition

    func testOptionSet_combinedPermissions_containsAll() {
        let permissions: JellyseerrPermissions = [.request, .vote, .request4KMovie]
        XCTAssertTrue(permissions.contains(.request))
        XCTAssertTrue(permissions.contains(.vote))
        XCTAssertTrue(permissions.contains(.request4KMovie))
        XCTAssertFalse(permissions.contains(.admin))
    }

    func testOptionSet_rawValueAddition() {
        let permissions = JellyseerrPermissions(rawValue: 32 + 64) // request + vote
        XCTAssertTrue(permissions.contains(.request))
        XCTAssertTrue(permissions.contains(.vote))
    }
}
