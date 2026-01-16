import Foundation
import Security

/// A manager for securely storing and retrieving credentials in the Keychain
/// with iCloud Keychain sync support for cross-device access
public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()

    private let serviceName = "com.cedricziel.seer"

    public enum KeychainKey: String, Sendable {
        case jellyfinServerURL = "jellyfin_server_url"
        case jellyfinAccessToken = "jellyfin_access_token"
        case jellyfinUserID = "jellyfin_user_id"
        case jellyfinDeviceID = "jellyfin_device_id"
        case jellyseerrServerURL = "jellyseerr_server_url"
        case jellyseerrAPIKey = "jellyseerr_api_key"
    }

    private init() {}

    /// Save a string value to the Keychain (synced via iCloud Keychain)
    @discardableResult
    public func save(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, for: key)
    }

    /// Save data to the Keychain (synced via iCloud Keychain)
    @discardableResult
    public func save(_ data: Data, for key: KeychainKey) -> Bool {
        // First delete any existing item (both synced and non-synced)
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            // Enable iCloud Keychain sync
            kSecAttrSynchronizable as String: true,
            // Accessible after first unlock, compatible with sync
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve a string value from the Keychain
    public func getString(for key: KeychainKey) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Retrieve data from the Keychain (checks both synced and local items)
    public func getData(for key: KeychainKey) -> Data? {
        // Query that matches both synced and non-synced items
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete a value from the Keychain (both synced and local)
    @discardableResult
    public func delete(for key: KeychainKey) -> Bool {
        // Delete synced items
        let syncedQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: true,
        ]
        SecItemDelete(syncedQuery as CFDictionary)

        // Also delete any non-synced items (legacy cleanup)
        let localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: false,
        ]
        SecItemDelete(localQuery as CFDictionary)

        return true
    }

    /// Delete all stored credentials
    public func deleteAll() {
        for key in [
            KeychainKey.jellyfinServerURL,
            KeychainKey.jellyfinAccessToken,
            KeychainKey.jellyfinUserID,
            KeychainKey.jellyfinDeviceID,
            KeychainKey.jellyseerrServerURL,
            KeychainKey.jellyseerrAPIKey,
        ] {
            delete(for: key)
        }
    }

    /// Check if credentials exist for a given key
    public func hasValue(for key: KeychainKey) -> Bool {
        getString(for: key) != nil
    }

    /// Migrate existing local keychain items to synced items
    /// Call this on app launch to ensure old items get synced
    public func migrateToSyncedKeychain() {
        for key in [
            KeychainKey.jellyfinServerURL,
            KeychainKey.jellyfinAccessToken,
            KeychainKey.jellyfinUserID,
            KeychainKey.jellyfinDeviceID,
            KeychainKey.jellyseerrServerURL,
            KeychainKey.jellyseerrAPIKey,
        ] {
            // Check for local-only item
            let localQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key.rawValue,
                kSecAttrSynchronizable as String: false,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(localQuery as CFDictionary, &result)

            if status == errSecSuccess, let data = result as? Data {
                // Re-save as synced item (this will delete the local one too)
                save(data, for: key)
            }
        }
    }
}
