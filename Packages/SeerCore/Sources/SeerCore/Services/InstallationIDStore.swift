import Foundation
import Security

struct InstallationIDStore {
    private let read: ([String: Any]) -> (OSStatus, Data?)
    private let add: ([String: Any]) -> OSStatus

    init(
        read: @escaping ([String: Any]) -> (OSStatus, Data?) = { query in
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result as? Data)
        },
        add: @escaping ([String: Any]) -> OSStatus = { item in
            SecItemAdd(item as CFDictionary, nil)
        }
    ) {
        self.read = read
        self.add = add
    }

    func installationID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.cedricziel.seer.telemetry",
            kSecAttrAccount as String: "installation_id",
            kSecAttrSynchronizable as String: false
        ]
        let (status, data) = readItem(query)
        if status == errSecSuccess {
            return decodeID(data)
        }
        guard status == errSecItemNotFound else { return nil }

        let identifier = UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(identifier.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        switch add(item) {
        case errSecSuccess:
            return identifier
        case errSecDuplicateItem:
            // Another caller may have created the item after our initial read.
            let (status, data) = readItem(query)
            return status == errSecSuccess ? decodeID(data) : nil
        default:
            return nil
        }
    }

    private func readItem(_ query: [String: Any]) -> (OSStatus, Data?) {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return read(query)
    }

    private func decodeID(_ data: Data?) -> String? {
        guard let data,
              let identifier = String(data: data, encoding: .utf8),
              UUID(uuidString: identifier) != nil else { return nil }
        return identifier
    }
}
