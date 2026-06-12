//
//  ChargeLocation.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – model/ChargersModel.kt
//

import CoreLocation
import Foundation

// MARK: - Listen-Element (Standort oder Cluster)

/// Element einer Charger-Liste: entweder eine Ladestation oder ein Cluster mehrerer Stationen.
enum ChargepointListItem: Sendable, Hashable {
    case location(ChargeLocation)
    case cluster(ChargeLocationCluster)

    var coordinate: Coordinate {
        switch self {
        case let .location(loc): return loc.coordinates
        case let .cluster(cluster): return cluster.coordinates
        }
    }
}

/// Ein serverseitig zusammengefasstes Cluster mehrerer Ladestationen.
struct ChargeLocationCluster: Sendable, Hashable {
    let clusterCount: Int
    let coordinates: Coordinate
    var items: [ChargeLocation]?
}

// MARK: - Ladestation

/// Eine ganze Ladestation (potenziell mit mehreren Ladepunkten).
struct ChargeLocation: Codable, Hashable, Sendable, Identifiable {
    let id: Int64
    /// Name der Datenquelle, z.B. "goingelectric".
    let dataSource: String
    let name: String
    let coordinates: Coordinate
    let address: Address?
    let chargepoints: [Chargepoint]
    /// Ladenetzwerk (Mobility Service Provider, MSP).
    let network: String?
    /// Link zur Datenquelle.
    let dataSourceUrl: String
    /// Link zu dieser Station bei der Datenquelle.
    let url: String?
    /// Link zum Bearbeiten der Station bei der Datenquelle.
    let editUrl: String?
    let faultReport: FaultReport?
    /// Bei crowdsourced Quellen: Daten wurden unabhängig verifiziert.
    let verified: Bool
    /// Ob die Station ohne vorherige Registrierung nutzbar ist.
    let barrierFree: Bool?
    // Nur in Detailansicht:
    let `operator`: String?
    let generalInformation: String?
    let amenities: String?
    let locationDescription: String?
    let photos: [ChargerPhoto]?
    let chargecards: [ChargeCardId]?
    let accessibility: String?
    let openinghours: OpeningHours?
    let cost: Cost?
    let license: String?
    let chargepriceData: ChargepriceData?
    let networkUrl: String?
    let chargerUrl: String?
    let timeRetrieved: Date
    /// Ob alle verfügbaren Details enthalten sind (Listen-Calls liefern oft nur Kurzform).
    let isDetailed: Bool

    /// SwiftUI/Identifiable: eindeutig über id + Datenquelle.
    var stableId: String { "\(dataSource):\(id)" }

    /// Stationsspezifische URL (GE, OCM). Nil wenn Quelle keine Pro-Station-Links hat (z.B. Nobil).
    var viewURL: String? { url }

    /// Quellenangabe-URL für Quellen ohne stationsspezifische Links (z.B. Nobil).
    var sourceURL: String? {
        guard url == nil else { return nil }
        return dataSourceUrl.isEmpty ? nil : dataSourceUrl
    }

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinates.lat, longitude: coordinates.lng)
    }

    /// Höchste verfügbare Leistung dieser Station.
    var maxPower: Double? { maxPower(connectors: nil) }

    /// Höchste Leistung über bestimmte Steckertypen.
    func maxPower(connectors: Set<String>?) -> Double? {
        chargepoints
            .filter { connectors?.contains($0.type) ?? true }
            .compactMap { $0.power }
            .max()
    }

    var totalChargepoints: Int {
        chargepoints.reduce(0) { $0 + $1.count }
    }

    /// Führt Ladepunkte mit gleichem Stecker und gleicher Leistung zusammen
    /// (z.B. Typ-2-Buchse und -Stecker, die in der GE-API nicht trennbar sind).
    var chargepointsMerged: [Chargepoint] {
        var seen = Set<String>()
        var variants: [Chargepoint] = []
        for cp in chargepoints {
            let powerKey: String = cp.power.map { String($0) } ?? "nil"
            let key = powerKey + "|" + cp.type
            if seen.insert(key).inserted { variants.append(cp) }
        }
        return variants.map { (variant: Chargepoint) -> Chargepoint in
            let filtered: [Chargepoint] = chargepoints.filter {
                $0.type == variant.type && $0.power == variant.power
            }
            let count: Int = filtered.reduce(0) { $0 + $1.count }
            let currents = Set(filtered.compactMap { $0.current })
            let voltages = Set(filtered.compactMap { $0.voltage })
            return Chargepoint(
                type: variant.type,
                power: variant.power,
                count: count,
                current: currents.count == 1 ? currents.first : nil,
                voltage: voltages.count == 1 ? voltages.first : nil
            )
        }
    }

    /// Ob mehrere (Schnell-)Ladepunkte vorhanden sind.
    func isMulti(filteredConnectors: Set<String>? = nil) -> Bool {
        var points = chargepointsMerged.filter { filteredConnectors?.contains($0.type) ?? true }
        if let maxP = maxPower(connectors: filteredConnectors), maxP >= 43 {
            // Schnelllader -> nur Schnelllader zählen
            points = points.filter { ($0.power ?? 0) >= 43 }
        }
        let connectors = Set(points.map(\.type))
        let perConnector = connectors.map { conn in
            points.filter { $0.type == conn }.reduce(0) { $0 + $1.count }
        }
        return perConnector.contains { $0 > 1 }
    }

    /// "2 × Typ 2 22 kW · 1 × CCS 50 kW"
    func formatChargepoints(locale: Locale = .current) -> String {
        chargepointsMerged.map { cp in
            let power = cp.formatPower(locale: locale).map { " \($0)" } ?? ""
            return "\(cp.count) × \(Chargepoint.Connector.displayName(for: cp.type))\(power)"
        }.joined(separator: " · ")
    }
}

// MARK: - Wertobjekte

struct Coordinate: Codable, Hashable, Sendable {
    let lat: Double
    let lng: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct Address: Codable, Hashable, Sendable {
    let city: String?
    let country: String?
    let postcode: String?
    let street: String?

    /// Deutsches Format: Straße, PLZ Stadt. (Länderabhängige Reihenfolge: TODO.)
    var formatted: String {
        var s = ""
        if let street {
            s += street
            if postcode != nil || city != nil { s += ", " }
        }
        if let postcode {
            s += postcode
            if city != nil { s += " " }
        }
        if let city { s += city }
        return s
    }
}

struct Cost: Codable, Hashable, Sendable {
    var freecharging: Bool?
    var freeparking: Bool?
    var descriptionShort: String?
    var descriptionLong: String?

    var isEmpty: Bool {
        descriptionLong == nil && descriptionShort == nil && freecharging == nil && freeparking == nil
    }
}

struct FaultReport: Codable, Hashable, Sendable {
    let created: Date?
    let description: String?
}

struct ChargeCardId: Codable, Hashable, Sendable {
    let id: Int64
}

/// Zusatzdaten für eine spätere Chargeprice-Integration.
struct ChargepriceData: Codable, Hashable, Sendable {
    let country: String?
    let network: String?
    let plugTypes: [String]?
}

// MARK: - Fotos

/// Foto einer Ladestation. Da die URL je Datenquelle unterschiedlich gebaut wird (GE braucht den
/// API-Key im Pfad), wird sie beim Konvertieren in der API-Schicht aufgelöst und hier als Vorlage
/// abgelegt: `{base}` enthält bereits Key + id, die Größenparameter werden angehängt.
struct ChargerPhoto: Codable, Hashable, Sendable {
    /// Quellenspezifische URL-Erzeugung (GE hängt Größenparameter an, OCM hat eigene URLs je Größe).
    enum Source: Codable, Hashable, Sendable {
        /// GE: Basis-URL inkl. Key/id, Größe wird angehängt.
        case goingElectric(baseURL: String)
        /// OCM: separate Thumb-/Large-URLs (medium via Namensersetzung).
        case openChargeMap(thumb: String, large: String)
        /// Generisch: kleine/große URL (z.B. Nobil).
        case simple(small: String, large: String)
    }

    let id: String
    let source: Source

    func url(height: Int? = nil, width: Int? = nil, size: Int? = nil) -> URL? {
        switch source {
        case let .goingElectric(baseURL):
            var suffix = ""
            if let size { suffix = "&size=\(size)" }
            else if let height { suffix = "&height=\(height)" }
            else if let width { suffix = "&width=\(width)" }
            return URL(string: baseURL + suffix)
        case let .openChargeMap(thumb, large):
            let medium = thumb.replacingOccurrences(of: ".thmb.", with: ".medi.")
            let maxSize = size ?? max(height ?? 0, width ?? 0)
            let chosen: String
            switch maxSize {
            case 0...100: chosen = thumb
            case 101...400: chosen = medium
            default: chosen = large
            }
            return URL(string: chosen)
        case let .simple(small, large):
            let maxSize = size ?? max(height ?? 0, width ?? 0)
            return URL(string: maxSize <= 100 ? small : large)
        }
    }
}

// MARK: - Öffnungszeiten

struct OpeningHours: Codable, Hashable, Sendable {
    let twentyfourSeven: Bool
    let description: String?
    let days: OpeningHoursDays?

    var isEmpty: Bool {
        description == "Leider noch keine Informationen zu Öffnungszeiten vorhanden."
            && days == nil && !twentyfourSeven
    }
}

struct OpeningHoursDays: Codable, Hashable, Sendable {
    let monday: Hours?
    let tuesday: Hours?
    let wednesday: Hours?
    let thursday: Hours?
    let friday: Hours?
    let saturday: Hours?
    let sunday: Hours?
    let holiday: Hours?

    func hours(for weekday: Int) -> Hours? {
        // weekday nach Calendar: 1=Sonntag … 7=Samstag
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return holiday
        }
    }
}

/// Uhrzeit-Bereich. Minutengenaue Tageszeit (0–1439).
struct Hours: Codable, Hashable, Sendable {
    /// Start in Minuten seit Mitternacht.
    let startMinutes: Int
    /// Ende in Minuten seit Mitternacht.
    let endMinutes: Int

    var startFormatted: String { Self.format(startMinutes) }
    var endFormatted: String { Self.format(endMinutes) }

    private static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    var description: String { "\(startFormatted) - \(endFormatted)" }
}
