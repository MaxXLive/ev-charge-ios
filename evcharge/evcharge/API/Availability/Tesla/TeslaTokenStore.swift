//
//  TeslaTokenStore.swift
//  evcharge
//
//  Gemeinsame Wahrheit für die Tesla-OAuth-Tokens (Keychain). Wird sowohl vom
//  UI-seitigen TeslaAuthManager als auch vom Owner-Detektor (Aktor) gelesen/geschrieben.
//  Android-Pendant: storage/EncryptedPreferenceDataStore.kt.
//

import Foundation

enum TeslaTokenStore {
    private static let refreshKey = "tesla_refresh_token"
    private static let accessKey = "tesla_access_token"
    private static let expiryKey = "tesla_access_token_expiry"
    private static let emailKey = "tesla_email"

    static var refreshToken: String? {
        get { KeychainHelper.read(refreshKey) }
        set {
            if let newValue { KeychainHelper.store(newValue, key: refreshKey) }
            else { KeychainHelper.delete(refreshKey) }
        }
    }

    static var accessToken: String? {
        get { KeychainHelper.read(accessKey) }
        set {
            if let newValue { KeychainHelper.store(newValue, key: accessKey) }
            else { KeychainHelper.delete(accessKey) }
        }
    }

    /// Ablaufzeitpunkt des Access-Tokens als Unix-Sekunden.
    static var accessTokenExpiry: Int64 {
        get { Int64(KeychainHelper.read(expiryKey) ?? "0") ?? 0 }
        set { KeychainHelper.store(String(newValue), key: expiryKey) }
    }

    static var email: String? {
        get { KeychainHelper.read(emailKey) }
        set {
            if let newValue { KeychainHelper.store(newValue, key: emailKey) }
            else { KeychainHelper.delete(emailKey) }
        }
    }

    static var hasRefreshToken: Bool { refreshToken != nil }

    /// Löscht sämtliche Tesla-Tokens (Logout).
    static func clear() {
        refreshToken = nil
        accessToken = nil
        KeychainHelper.delete(expiryKey)
        email = nil
    }
}
