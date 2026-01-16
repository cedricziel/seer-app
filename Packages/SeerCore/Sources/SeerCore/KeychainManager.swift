import Foundation
import Security

/// A manager for securely storing and retrieving credentials in the Keychain
/// with iCloud Keychain sync support for cross-device access
public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()

    private let serviceName = "com.cedricziel.seer"

    // MARK: - Legacy Keys (for single-server migration)

    public enum KeychainKey: String, Sendable {
        case jellyfinServerURL = "jellyfin_server_url"
        case jellyfinAccessToken = "jellyfin_access_token"
        case jellyfinUserID = "jellyfin_user_id"
        case jellyfinDeviceID = "jellyfin_device_id"
        case jellyseerrServerURL = "jellyseerr_server_url"
        case jellyseerrAPIKey = "jellyseerr_api_key"
    }

    // MARK: - Server-Specific Credential Keys

    public enum ServerCredentialKey: String, Sendable {
        case jellyfinAccessToken = "jellyfin_token"
        case jellyfinDeviceID = "jellyfin_device_id"
        case jellyseerrAPIKey = "jellyseerr_api_key"
    }

    private init() {}

    // MARK: - Server-Specific Credentials

    /// Generate a keychain key for a specific server and credential type
    private func serverKey(for serverID: UUID, key: ServerCredentialKey) -> String {
        "server_\(serverID.uuidString)_\(key.rawValue)"
    }

    /// Save a credential for a specific server
    @discardableResult
    public func saveCredential(_ value: String, for serverID: UUID, key: ServerCredentialKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveCredentialData(data, for: serverID, key: key)
    }

    /// Save credential data for a specific server
    @discardableResult
    public func saveCredentialData(_ data: Data, for serverID: UUID, key: ServerCredentialKey) -> Bool {
        let keyString = serverKey(for: serverID, key: key)

        // First delete any existing item
        deleteCredential(for: serverID, key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyString,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Get a credential for a specific server
    public func getCredential(for serverID: UUID, key: ServerCredentialKey) -> String? {
        guard let data = getCredentialData(for: serverID, key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Get credential data for a specific server
    public func getCredentialData(for serverID: UUID, key: ServerCredentialKey) -> Data? {
        let keyString = serverKey(for: serverID, key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete a credential for a specific server
    @discardableResult
    public func deleteCredential(for serverID: UUID, key: ServerCredentialKey) -> Bool {
        let keyString = serverKey(for: serverID, key: key)

        // Delete synced items
        let syncedQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyString,
            kSecAttrSynchronizable as String: true,
        ]
        SecItemDelete(syncedQuery as CFDictionary)

        // Also delete any non-synced items
        let localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyString,
            kSecAttrSynchronizable as String: false,
        ]
        SecItemDelete(localQuery as CFDictionary)

        return true
    }

    /// Get all credentials for a specific server
    public func getServerCredentials(for serverID: UUID) -> ServerCredentials {
        ServerCredentials(
            jellyfinAccessToken: getCredential(for: serverID, key: .jellyfinAccessToken),
            jellyfinDeviceID: getCredential(for: serverID, key: .jellyfinDeviceID),
            jellyseerrAPIKey: getCredential(for: serverID, key: .jellyseerrAPIKey)
        )
    }

    /// Save all credentials for a specific server
    public func saveServerCredentials(_ credentials: ServerCredentials, for serverID: UUID) {
        if let token = credentials.jellyfinAccessToken {
            saveCredential(token, for: serverID, key: .jellyfinAccessToken)
        }
        if let deviceID = credentials.jellyfinDeviceID {
            saveCredential(deviceID, for: serverID, key: .jellyfinDeviceID)
        }
        if let apiKey = credentials.jellyseerrAPIKey {
            saveCredential(apiKey, for: serverID, key: .jellyseerrAPIKey)
        }
    }

    /// Delete all credentials for a specific server
    public func deleteServerCredentials(for serverID: UUID) {
        deleteCredential(for: serverID, key: .jellyfinAccessToken)
        deleteCredential(for: serverID, key: .jellyfinDeviceID)
        deleteCredential(for: serverID, key: .jellyseerrAPIKey)
    }

    // MARK: - Legacy Single-Server Methods (kept for migration)

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

    /// Delete all stored legacy credentials
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

    /// Check if legacy single-server credentials exist (for migration)
    public func hasLegacyCredentials() -> Bool {
        getString(for: .jellyfinServerURL) != nil
    }
}
