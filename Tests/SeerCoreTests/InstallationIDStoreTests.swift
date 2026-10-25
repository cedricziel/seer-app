import Foundation
import Security
@testable import SeerCore
import XCTest

final class InstallationIDStoreTests: XCTestCase {
    func testReadingExistingIDDoesNotCreateOne() {
        let keychain = InMemoryInstallationKeychain()
        XCTAssertNil(keychain.store().existingID())
        XCTAssertNil(keychain.savedItem)
    }

    func testCreatesUUIDAndReusesItAcrossStoreInstances() throws {
        let keychain = InMemoryInstallationKeychain()
        let first = try XCTUnwrap(keychain.store().installationID())

        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(keychain.store().installationID(), first)
    }

    func testStoresIDLocallyWithoutSyncOrDeviceMigration() throws {
        let keychain = InMemoryInstallationKeychain()
        _ = try XCTUnwrap(keychain.store().installationID())

        XCTAssertEqual(keychain.savedItem?[kSecAttrSynchronizable as String] as? Bool, false)
        XCTAssertEqual(
            keychain.savedItem?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
    }

    func testUnavailableKeychainDoesNotCreateAnID() {
        let keychain = InMemoryInstallationKeychain()
        keychain.readStatus = errSecInteractionNotAllowed

        XCTAssertNil(keychain.store().installationID())
        XCTAssertNil(keychain.savedItem)
    }

    func testFailedWriteDoesNotReturnAnEphemeralID() {
        let keychain = InMemoryInstallationKeychain()
        keychain.addStatus = errSecNotAvailable

        XCTAssertNil(keychain.store().installationID())
    }

    func testDuplicateWriteReturnsThePersistedWinner() {
        let keychain = InMemoryInstallationKeychain()
        let winner = UUID().uuidString
        keychain.concurrentID = winner

        XCTAssertEqual(keychain.store().installationID(), winner)
    }

    func testInvalidStoredValueIsOmittedWithoutOverwritingIt() {
        let keychain = InMemoryInstallationKeychain()
        keychain.data = Data("invalid".utf8)

        XCTAssertNil(keychain.store().installationID())
        XCTAssertNil(keychain.savedItem)
    }
}

private final class InMemoryInstallationKeychain {
    var data: Data?
    var savedItem: [String: Any]?
    var readStatus: OSStatus?
    var addStatus: OSStatus = errSecSuccess
    var concurrentID: String?

    func store() -> InstallationIDStore {
        InstallationIDStore(
            read: { _ in
                (self.readStatus ?? (self.data == nil ? errSecItemNotFound : errSecSuccess), self.data)
            },
            add: { item in
                if let concurrentID = self.concurrentID {
                    self.data = Data(concurrentID.utf8)
                    return errSecDuplicateItem
                }
                guard self.addStatus == errSecSuccess else { return self.addStatus }
                self.savedItem = item
                self.data = item[kSecValueData as String] as? Data
                return errSecSuccess
            }
        )
    }
}
