//
//  AvailabilityService.swift
//  evmap
//
//  Wählt den passenden Verfügbarkeits-Detektor (v1: EnBW) und liefert den Status.
//

import Foundation

actor AvailabilityService {
    private let detectors: [any AvailabilityDetector]

    init() {
        // v1: nur EnBW. Weitere Detektoren (Tesla, Chargecloud …) hier ergänzen.
        detectors = [EnBwAvailabilityDetector()]
    }

    /// Versucht der Reihe nach alle unterstützenden Detektoren; nil, wenn keiner Daten liefert.
    func availability(for location: ChargeLocation) async -> ChargeLocationStatus? {
        for detector in detectors where detector.isSupported(location) {
            if let status = try? await detector.getAvailability(location) {
                return status
            }
        }
        return nil
    }
}
