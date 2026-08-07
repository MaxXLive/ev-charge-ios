//
//  TeslaAuthApi.swift
//  evcharge
//
//  Tesla OAuth2 (PKCE) + Nutzerinfo. Portiert aus
//  api/availability/tesla/TeslaOwnerApi.kt (TeslaAuthenticationApi/TeslaOwnerApi).
//

import CryptoKit
import Foundation

enum TeslaAuthError: Error { case http(Int), invalidResponse, refreshTokenInvalid }

actor TeslaAuthApi {
    private let session: URLSession
    private let authBase = "https://auth.tesla.com"
    private let ownerBase = "https://owner-api.teslamotors.com"

    static let redirectURI = "tesla://auth/callback"
    static let callbackScheme = "tesla"
    static let clientID = "ownerapi"
    private static let scope = "openid email offline_access"

    // Header, die Tesla für die App-APIs erwartet (exakt wie Android).
    private static let teslaUserAgent = "TeslaApp/4.44.5-3304/3a5d531cc3/android/27"
    private static let userAgent = "okhttp/4.11.0"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - PKCE

    nonisolated static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLNoPad(Data(bytes))
    }

    nonisolated static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLNoPad(Data(digest))
    }

    nonisolated private static func base64URLNoPad(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Login-URL für die Web-Authentifizierung.
    nonisolated static func signInURL(codeChallenge: String) -> URL {
        var comps = URLComponents(string: "https://auth.tesla.com/oauth2/v3/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email offline_access phone"),
            .init(name: "is_in_app", value: "true"),
            .init(name: "state", value: "123"),
        ]
        return comps.url!
    }

    // MARK: - Token

    func exchangeCode(_ code: String, verifier: String) async throws -> TeslaOAuthResponse {
        try await token(body: [
            "grant_type": "authorization_code",
            "client_id": Self.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": Self.redirectURI,
            "scope": Self.scope,
        ])
    }

    func refresh(_ refreshToken: String) async throws -> TeslaOAuthResponse {
        try await token(body: [
            "grant_type": "refresh_token",
            "client_id": Self.clientID,
            "refresh_token": refreshToken,
            "scope": Self.scope,
        ], treat401As: TeslaAuthError.refreshTokenInvalid)
    }

    private func token(body: [String: String], treat401As: Error? = nil) async throws -> TeslaOAuthResponse {
        var req = URLRequest(url: URL(string: authBase + "/oauth2/v3/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            if code == 401, let mapped = treat401As { throw mapped }
            throw TeslaAuthError.http(code)
        }
        return try JSONDecoder().decode(TeslaOAuthResponse.self, from: data)
    }

    // MARK: - Nutzerinfo

    func userEmail(accessToken: String) async throws -> String {
        var req = URLRequest(url: URL(string: ownerBase + "/api/1/users/me")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(Self.teslaUserAgent, forHTTPHeaderField: "x-tesla-user-agent")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw TeslaAuthError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(TeslaUserInfoResponse.self, from: data).response.email
    }

    // MARK: - Header für Charging-GraphQL

    nonisolated static func applyTeslaHeaders(_ req: inout URLRequest, bearer: String) {
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(teslaUserAgent, forHTTPHeaderField: "x-tesla-user-agent")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}
