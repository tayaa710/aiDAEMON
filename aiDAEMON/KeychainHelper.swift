import Foundation
import Security

// MARK: - KeychainHelper
//
// Secure string storage backed by macOS Keychain.
// ALL API keys and credentials MUST use this — never UserDefaults, plain files, or source code.
//
// Service identifier: com.aidaemon
// Uses kSecClassGenericPassword with the caller-supplied key as the account name.

public enum KeychainHelper {

    private static let service = "com.aidaemon"

    // MARK: - Save

    /// Store a UTF-8 string in the Keychain.
    /// Silently overwrites any existing value for the same key.
    /// - Parameters:
    ///   - key: Account name (used to look up the value later; never the secret itself).
    ///   - value: The secret string to store.
    /// - Returns: `true` on success, `false` if the Keychain operation failed.
    @discardableResult
    public static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Remove any existing entry first — SecItemAdd fails if the key already exists.
        delete(key: key)

        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("KeychainHelper: save failed for key '%@' (OSStatus %d)", key, status)
        }
        return status == errSecSuccess
    }

    // MARK: - Load

    /// Retrieve a string from the Keychain.
    /// - Parameter key: The account name used when saving.
    /// - Returns: The stored string, or `nil` if the key does not exist or cannot be decoded.
    public static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  key,
            kSecReturnData:   kCFBooleanTrue as Any,
            kSecMatchLimit:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    // MARK: - Delete

    /// Remove a value from the Keychain.
    /// - Parameter key: The account name to remove.
    /// - Returns: `true` on success or if the item did not exist.
    @discardableResult
    public static func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
