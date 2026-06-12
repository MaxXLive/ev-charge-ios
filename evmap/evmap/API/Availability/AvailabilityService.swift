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
        // Reihenfolge zählt: erster Detektor mit Daten gewinnt.
        // Tesla-Owner vor -Gast (Login schaltet mehr Daten frei); EnBW schließt Tesla ohnehin aus.
        detectors = [
            TeslaOwnerAvailabilityDetector(),
            TeslaGuestAvailabilityDetector(),
            EnBwAvailabilityDetector(),
        ]
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
