//
//  TeslaAuthManager.swift
//  evmap
//
//  Steuert den Tesla-Login (OAuth2/PKCE über ASWebAuthenticationSession) und hält
//  den Anmeldezustand für die UI. Tokens liegen in der Keychain ([[TeslaTokenStore]]).
//

import AuthenticationServices
import Observation
import SwiftUI

@MainActor
@Observable
final class TeslaAuthManager: NSObject {
    /// E-Mail des angemeldeten Kontos, nil wenn abgemeldet.
    var email: String?
    /// Login läuft gerade (für Spinner/Disable).
    var isWorking = false

    private let authApi = TeslaAuthApi()
    private var session: ASWebAuthenticationSession?

    var isLoggedIn: Bool { email != nil }

    override init() {
        self.email = TeslaTokenStore.email
        super.init()
    }

    /// Startet den Web-Login-Flow und speichert die Tokens.
    func login() async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let verifier = TeslaAuthApi.generateCodeVerifier()
        let challenge = TeslaAuthApi.codeChallenge(for: verifier)
        let url = TeslaAuthApi.signInURL(codeChallenge: challenge)

        let callback = try await authenticate(url: url)
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw TeslaAuthError.invalidResponse }

        let resp = try await authApi.exchangeCode(code, verifier: verifier)
        let email = try await authApi.userEmail(accessToken: resp.accessToken)

        TeslaTokenStore.refreshToken = resp.refreshToken
        TeslaTokenStore.accessToken = resp.accessToken
        TeslaTokenStore.accessTokenExpiry = Int64(Date().timeIntervalSince1970) + resp.expiresIn
        TeslaTokenStore.email = email
        self.email = email
    }

    func logout() {
        TeslaTokenStore.clear()
        email = nil
    }

    // MARK: - ASWebAuthenticationSession

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: TeslaAuthApi.callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? TeslaAuthError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }
}

extension TeslaAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
