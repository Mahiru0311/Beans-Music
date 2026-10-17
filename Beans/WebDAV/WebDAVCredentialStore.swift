import Foundation
import Security

// Only connection metadata is backed up; passwords are stored with device-only Keychain protection.
enum WebDAVCredentialStore {
    private static let service = "com.beans.webdav"

    static func save(password: String, id: UUID) throws {
        let query = baseQuery(id)
        let attributes: [String: Any] = [kSecValueData as String: Data(password.utf8),
                                        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw WebDAVError.keychain(added) }
        } else if status != errSecSuccess { throw WebDAVError.keychain(status) }
    }

    static func password(id: UUID) throws -> String? {
        var query = baseQuery(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8) else { throw WebDAVError.keychain(status) }
        return string
    }

    static func remove(id: UUID) throws {
        let status = SecItemDelete(baseQuery(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw WebDAVError.keychain(status) }
    }

    private static func baseQuery(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString]
    }
}
