import Foundation
import Security

/// Storage seam for secrets. The product path uses `KeychainSecretStore`;
/// tests inject `InMemorySecretStore`, because the headless simulator has no
/// usable keychain without code signing and a secret must never fall back to
/// UserDefaults just to keep a test green.
protocol KitchenLinkSecretStore {
    func load(account: String) -> Data?
    /// Returns `false` when the secret could not be stored (e.g. keychain
    /// unavailable). Callers decide whether that is worth surfacing.
    @discardableResult
    func save(_ data: Data, account: String) -> Bool
    @discardableResult
    func delete(account: String) -> Bool
}

struct KeychainSecretStore: KitchenLinkSecretStore {
    let service: String

    init(service: String) {
        self.service = service
    }

    func load(account: String) -> Data? {
        KitchenLinkKeychain.load(service: service, account: account)
    }

    @discardableResult
    func save(_ data: Data, account: String) -> Bool {
        KitchenLinkKeychain.save(data: data, service: service, account: account)
    }

    @discardableResult
    func delete(account: String) -> Bool {
        KitchenLinkKeychain.delete(service: service, account: account)
    }
}

#if DEBUG
/// Test double: keeps secrets in memory for the lifetime of the instance.
final class InMemorySecretStore: KitchenLinkSecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    init() {}

    func load(account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return items[account]
    }

    @discardableResult
    func save(_ data: Data, account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        items[account] = data
        return true
    }

    @discardableResult
    func delete(account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        items.removeValue(forKey: account)
        return true
    }
}
#endif

enum KitchenLinkKeychain {
    /// Returns `true` when the operation succeeded or when the item is
    /// already absent (delete-only). `false` means the keychain is
    /// unavailable (e.g. headless simulator without code signing).
    @discardableResult
    static func save(data: Data, service: String, account: String) -> Bool {
        // Delete existing first so we can insert fresh.
        _ = delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
