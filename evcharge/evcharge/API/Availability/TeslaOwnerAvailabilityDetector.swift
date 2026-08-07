//
//  TeslaOwnerAvailabilityDetector.swift
//  evcharge
//
//  Echtzeit-Verfügbarkeit + Besitzer-/Mitglieds-Preise für Tesla Supercharger,
//  wenn ein Tesla-Konto angemeldet ist. Portiert aus
//  api/availability/TeslaOwnerAvailabilityDetector.kt.
//

import Foundation

actor TeslaOwnerAvailabilityDetector: AvailabilityDetector {
    private let authApi: TeslaAuthApi
    private let ownerApi: TeslaOwnerApi

    init(session: URLSession = .shared) {
        let auth = TeslaAuthApi(session: session)
        self.authApi = auth
        self.ownerApi = TeslaOwnerApi(session: session) {
            // Gültiges Access-Token liefern, bei Ablauf per Refresh-Token erneuern.
            let now = Int64(Date().timeIntervalSince1970)
            if let access = TeslaTokenStore.accessToken, TeslaTokenStore.accessTokenExpiry > now {
                return access
            }
            guard let refresh = TeslaTokenStore.refreshToken else { throw TeslaAuthError.refreshTokenInvalid }
            do {
                let resp = try await auth.refresh(refresh)
                TeslaTokenStore.accessToken = resp.accessToken
                TeslaTokenStore.accessTokenExpiry = now + resp.expiresIn
                return resp.accessToken
            } catch TeslaAuthError.refreshTokenInvalid {
                // Refresh-Token ungültig → abmelden.
                TeslaTokenStore.refreshToken = nil
                throw TeslaAuthError.refreshTokenInvalid
            }
        }
    }

    nonisolated func isSupported(_ location: ChargeLocation) -> Bool {
        TeslaSupport.isSupercharger(location)
            && TeslaTokenStore.hasRefreshToken
            && !location.chargepoints.isEmpty
            && location.chargepoints.allSatisfy { $0.hasKnownPower }
    }

    func getAvailability(_ location: ChargeLocation) async throws -> ChargeLocationStatus {
        let guid = try await ownerApi.nearestLocationGUID(
            lat: location.coordinates.lat, lng: location.coordinates.lng
        )
        let site = try await ownerApi.siteInformation(locationGUID: guid)

        // Labels notfalls aus siteStatic ergänzen (id → label).
        let staticLabels = Dictionary(
            site.siteStatic.chargers.map { ($0.id.text, $0.label?.value) },
            uniquingKeysWith: { a, _ in a }
        )
        let stalls = site.siteDynamic.chargerDetails.map { detail in
            TeslaStall(
                status: detail.availability.status,
                label: detail.charger.label?.value ?? staticLabels[detail.charger.id.text] ?? nil
            )
        }
        guard !stalls.isEmpty else { throw AvailabilityError.noMatch }

        let entries = TeslaStallMatcher.match(stalls: stalls, to: location.chargepointsMerged)
        let utilization = Self.utilization(from: site.congestionPriceHistogram)

        return ChargeLocationStatus(
            source: "Tesla",
            entries: entries,
            lastChange: nil,
            pricing: site.pricing,
            utilization: utilization
        )
    }

    /// Histogramm-Werte (0–1) so rotieren, dass 0 Uhr vorn steht, und in Prozent wandeln.
    private static func utilization(from histogram: OwnerSiteInfoResponse.CongestionHistogram?) -> [TeslaUtilizationBucket]? {
        guard let histogram, !histogram.data.isEmpty,
              let midnight = histogram.dataAttributes.firstIndex(where: { $0.label == "12AM" })
        else { return nil }
        let n = histogram.data.count
        return (0 ..< n).map { i in
            let value = histogram.data[(i + midnight) % n]
            return TeslaUtilizationBucket(hour: i, percent: Int((value * 100).rounded()))
        }
    }
}
