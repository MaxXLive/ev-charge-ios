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
    /// Tesla-Preisstruktur (nur bei Tesla Superchargern).
    var pricing: TeslaPricing? = nil
    /// Durchschnittliche Auslastung je Stunde (nur Tesla-Owner-Pfad).
    var utilization: [TeslaUtilizationBucket]? = nil

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

// MARK: - Tesla

/// Erkennt Tesla Supercharger über die jeweiligen Quellen-Felder (Android-Pendant:
/// `isChargerSupported` in beiden Tesla-Detektoren).
enum TeslaSupport {
    nonisolated static func isSupercharger(_ location: ChargeLocation) -> Bool {
        switch location.dataSource {
        case "goingelectric": return location.network == "Tesla Supercharger"
        case "nobil": return location.network == "Tesla"
        case "openchargemap": return ["23", "3534"].contains(location.chargepriceData?.network ?? "")
        case "openstreetmap": return ["Tesla, Inc.", "Tesla"].contains(location.operator ?? "")
        default: return false
        }
    }
}

/// Ein einzelner Tesla-Stall mit Status und (optionalem) Label wie "1A", "12".
struct TeslaStall: Sendable {
    let status: ChargepointStatus
    let label: String?

    /// Zahlenanteil des Labels (zum Sortieren), nil wenn keiner.
    var labelNumber: Int? { label.flatMap { Int($0.filter(\.isNumber)) } }
    /// Buchstabenanteil des Labels.
    var labelLetter: String { label?.filter { !$0.isNumber } ?? "" }
}

/// Verteilt die (nach Label sortierten) Tesla-Stalls auf die zusammengeführten Ladepunkte.
/// Vereinfacht ggü. Android: ordnet rein der Reihe nach zu, fehlende Stalls = unknown.
enum TeslaStallMatcher {
    nonisolated static func match(stalls: [TeslaStall], to chargepoints: [Chargepoint]) -> [AvailabilityEntry] {
        var sorted = stalls.sorted {
            let n0 = $0.labelNumber ?? Int.max, n1 = $1.labelNumber ?? Int.max
            if n0 != n1 { return n0 < n1 }
            return $0.labelLetter < $1.labelLetter
        }
        let total = chargepoints.reduce(0) { $0 + $1.count }
        if sorted.count < total {
            sorted += Array(repeating: TeslaStall(status: .unknown, label: nil), count: total - sorted.count)
        }
        var index = 0
        return chargepoints.map { cp in
            let slice = sorted[index ..< min(index + cp.count, sorted.count)]
            index += cp.count
            let statuses = slice.isEmpty
                ? Array(repeating: ChargepointStatus.unknown, count: cp.count)
                : slice.map(\.status)
            return AvailabilityEntry(chargepoint: cp, statuses: statuses)
        }
    }
}
