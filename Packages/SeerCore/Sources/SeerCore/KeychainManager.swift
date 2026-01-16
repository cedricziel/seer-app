import Foundation
import Security

/// A manager for securely storing and retrieving credentials in the Keychain
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

    /// Save a string value to the Keychain
    @discardableResult
    public func save(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, for: key)
    }

    /// Save data to the Keychain
    @discardableResult
    public func save(_ data: Data, for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve a string value from the Keychain
    public func getString(for key: KeychainKey) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Retrieve data from the Keychain
    public func getData(for key: KeychainKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete a value from the Keychain
    @discardableResult
    public func delete(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
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
}
