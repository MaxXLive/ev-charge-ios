//
//  KeychainHelper.swift
//  evmap
//
//  Dünner Wrapper um die Keychain (Security-Framework) für sensible Tokens
//  (Tesla OAuth). Zustandslos → von UI und Aktoren gleichermaßen nutzbar.
//

import Foundation
import Security

enum KeychainHelper {
    /// Speichert (oder ersetzt) einen String unter `key`.
    static func store(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        // Bestehenden Eintrag entfernen, dann neu anlegen (idempotent).
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Liest den String unter `key`, falls vorhanden.
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    /// Löscht den Eintrag unter `key` (No-op, wenn keiner existiert).
    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
