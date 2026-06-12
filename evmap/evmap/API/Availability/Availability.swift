//
//  Availability.swift
//  evmap
//
//  Echtzeit-Verfügbarkeit (Android-Pendant: api/availability/).
//  Quellenunabhängiges Modell + Detektor-Protokoll.
//

import Foundation
import SwiftUI

enum ChargepointStatus: Sendable, Equatable {
    case available, unknown, charging, occupied, faulted

    var color: Color {
        switch self {
        case .available: return EVMapColor.available
        case .charging: return Color(hex: 0x00BCD4)
        case .occupied: return EVMapColor.unavailable
        case .faulted: return EVMapColor.unavailable
        case .unknown: return Color(hex: 0x9E9E9E)
        }
    }

    /// „frei" zählt nur AVAILABLE.
    var isAvailable: Bool { self == .available }
    var isKnown: Bool { self != .unknown }
}

/// Verfügbarkeit eines (zusammengeführten) Ladepunkts.
struct AvailabilityEntry: Sendable, Identifiable {
    let chargepoint: Chargepoint
    let statuses: [ChargepointStatus]

    var id: String { "\(chargepoint.type)|\(chargepoint.power.map { String($0) } ?? "?")" }
    var total: Int { statuses.count }
    var availableCount: Int { statuses.filter { $0.isAvailable }.count }
    var anyKnown: Bool { statuses.contains { $0.isKnown } }

    /// Ampelfarbe: alle frei = grün, einige = amber, keine = rot, unbekannt = grau.
    var color: Color {
        guard anyKnown, total > 0 else { return Color(hex: 0x9E9E9E) }
        if availableCount == total { return EVMapColor.available }
        if availableCount > 0 { return EVMapColor.someAvailable }
        return EVMapColor.unavailable
    }
}

/// Verfügbarkeitsstatus einer ganzen Ladestation.
struct ChargeLocationStatus: Sendable {
    let source: String
    let entries: [AvailabilityEntry]
    let lastChange: Date?

    var totalAvailable: Int { entries.reduce(0) { $0 + $1.availableCount } }
    var total: Int { entries.reduce(0) { $0 + $1.total } }
}

enum AvailabilityError: Error { case noMatch, noCandidate, http(Int) }

protocol AvailabilityDetector: Sendable {
    /// Grobe Einschätzung, ob diese Quelle den Charger unterstützt.
    nonisolated func isSupported(_ location: ChargeLocation) -> Bool
    func getAvailability(_ location: ChargeLocation) async throws -> ChargeLocationStatus
}

// MARK: - Matching-Hilfe

enum AvailabilityMatcher {
    /// Ordnet EnBW-/Quellen-Connectoren den zusammengeführten Ladepunkten zu (vereinfacht ggü. Android).
    nonisolated static func match(
        connectors: [(type: String, power: Double?, status: ChargepointStatus)],
        to chargepoints: [Chargepoint]
    ) -> [AvailabilityEntry] {
        var remaining = connectors
        return chargepoints.map { cp in
            let equiv = equivalentPlugTypes(cp.type)
            var candidates = remaining.filter { equiv.contains($0.type) }
            // Bei mehr Treffern als Plätzen nach Leistung eingrenzen.
            if candidates.count > cp.count, let power = cp.power {
                let byPower = candidates.filter { abs(($0.power ?? 0) - power) < 1 }
                if !byPower.isEmpty { candidates = byPower }
            }
            let picked = Array(candidates.prefix(cp.count))
            // verbrauchte Connectoren entfernen (per Identität über Index)
            for p in picked {
                if let idx = remaining.firstIndex(where: {
                    $0.type == p.type && $0.power == p.power && $0.status == p.status
                }) {
                    remaining.remove(at: idx)
                }
            }
            let statuses = picked.isEmpty
                ? Array(repeating: ChargepointStatus.unknown, count: cp.count)
                : picked.map { $0.status }
            return AvailabilityEntry(chargepoint: cp, statuses: statuses)
        }
    }
}
