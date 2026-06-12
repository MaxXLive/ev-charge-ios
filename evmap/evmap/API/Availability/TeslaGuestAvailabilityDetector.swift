//
//  TeslaGuestAvailabilityDetector.swift
//  evmap
//
//  Echtzeit-Verfügbarkeit + Gast-Preise für Tesla Supercharger ohne Login.
//  Portiert aus api/availability/TeslaGuestAvailabilityDetector.kt.
//

import CoreLocation
import Foundation

actor TeslaGuestAvailabilityDetector: AvailabilityDetector {
    private let guestApi: TeslaGuestApi

    init(session: URLSession = .shared) {
        self.guestApi = TeslaGuestApi(session: session)
    }

    nonisolated func isSupported(_ location: ChargeLocation) -> Bool {
        TeslaSupport.isSupercharger(location)
            && !location.chargepoints.isEmpty
            && location.chargepoints.allSatisfy { $0.hasKnownPower }
    }

    func getAvailability(_ location: ChargeLocation) async throws -> ChargeLocationStatus {
        let lat = location.coordinates.lat
        let lng = location.coordinates.lng

        let locations = try await guestApi.locations()
        guard let nearest = locations.min(by: { a, b in
            distance(a, lat, lng) < distance(b, lat, lng)
        }), let trtId = nearest.trtId.flatMap({ Int64($0) }) else {
            throw AvailabilityError.noCandidate
        }

        // ADHOC: Verfügbarkeit + Ad-hoc-Preise. GUEST: Gast-Preise (parallel).
        async let adhocTask = guestApi.siteDetails(trtId: trtId, experience: .adhoc)
        async let guestTask = guestApi.siteDetails(trtId: trtId, experience: .guest)
        guard let adhoc = try await adhocTask else { throw AvailabilityError.noCandidate }
        let guestSite = try? await guestTask

        let stalls = adhoc.chargerList.map {
            TeslaStall(status: $0.availability.status, label: $0.label)
        }
        guard !stalls.isEmpty else { throw AvailabilityError.noMatch }

        let entries = TeslaStallMatcher.match(stalls: stalls, to: location.chargepointsMerged)
        let pricing = Self.mergePricing(adhoc: adhoc.pricing, guest: guestSite?.pricing)

        return ChargeLocationStatus(source: "Tesla", entries: entries, lastChange: nil, pricing: pricing)
    }

    /// Mitglieds-Spalte = Gast-Tarif, Andere-Spalte = Ad-hoc-Tarif (wie Android).
    private static func mergePricing(adhoc: TeslaPricing?, guest: TeslaPricing?) -> TeslaPricing? {
        let guestRates = guest?.userRates
        if let adhoc {
            return TeslaPricing(
                memberRates: guestRates,
                userRates: adhoc.userRates,
                hasMembershipPricing: adhoc.hasMembershipPricing,
                hasMSPPricing: adhoc.hasMSPPricing,
                canDisplayCombinedComparison: adhoc.canDisplayCombinedComparison
            )
        }
        guard let guestRates else { return nil }
        return TeslaPricing(
            memberRates: guestRates, userRates: nil,
            hasMembershipPricing: nil, hasMSPPricing: nil, canDisplayCombinedComparison: nil
        )
    }

    private func distance(_ loc: TeslaCuaLocation, _ lat: Double, _ lng: Double) -> Double {
        guard let la = loc.latitude, let lo = loc.longitude else { return .greatestFiniteMagnitude }
        return CLLocation(latitude: la, longitude: lo)
            .distance(from: CLLocation(latitude: lat, longitude: lng))
    }
}
