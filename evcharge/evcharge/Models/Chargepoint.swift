//
//  Chargepoint.swift
//  evcharge
//
//  Portiert aus EVMap (Android, MIT) – model/ChargersModel.kt
//  Eine Steckdose/Stecker eines bestimmten Typs, ggf. mehrfach an einer ChargeLocation.
//

import Foundation

/// Ein Ladepunkt (Stecker/Buchse) mit Leistung, der an einer Ladestation mehrfach vorhanden sein kann.
struct Chargepoint: Codable, Hashable, Sendable {
    /// Steckertyp – möglichst eine der Konstanten aus `Connector`.
    let type: String
    /// Leistung in kW (nil = unbekannt).
    let power: Double?
    /// Anzahl dieser Stecker/Buchsen.
    let count: Int
    /// Max. Strom in A (nil = unbekannt).
    var current: Double?
    /// Max. Spannung in V (nil = unbekannt). Hinweis: bei DC kann current * voltage > power sein.
    var voltage: Double?
    /// EVSE-IDs der einzelnen Stecker.
    var evseIds: [String?]?
    /// EVSE-Unique-IDs der einzelnen Stecker.
    var evseUIds: [String?]?

    init(
        type: String,
        power: Double?,
        count: Int,
        current: Double? = nil,
        voltage: Double? = nil,
        evseIds: [String?]? = nil,
        evseUIds: [String?]? = nil
    ) {
        self.type = type
        self.power = power
        self.count = count
        self.current = current
        self.voltage = voltage
        self.evseIds = evseIds
        self.evseUIds = evseUIds
    }

    var hasKnownPower: Bool { power != nil }
    var hasKnownVoltageAndCurrent: Bool { voltage != nil && current != nil }

    /// Formatiert die Leistung, z.B. "22 kW" / "3.7 kW". nil wenn unbekannt.
    func formatPower(locale: Locale = .current) -> String? {
        guard let power else { return nil }
        let fmt = NumberFormatter()
        fmt.locale = locale
        fmt.minimumFractionDigits = 0
        // Ganze Zahl ohne Nachkommastelle, sonst eine Nachkommastelle.
        fmt.maximumFractionDigits = abs(power - power.rounded(.towardZero)) < 0.1 ? 0 : 1
        guard let s = fmt.string(from: power as NSNumber) else { return nil }
        return "\(s) kW"
    }

    func formatVoltageAndCurrent() -> String? {
        guard let current, let voltage else { return nil }
        return String(format: "%.0f V · %.0f A", voltage, current)
    }

    /// Interne Steckertyp-Konstanten (quellenunabhängig). Strings identisch zum Android-Original
    /// für Datenkompatibilität.
    enum Connector {
        static let type1 = "Type 1"
        static let type2Unknown = "Type 2 (either plug or socket)"
        static let type2Socket = "Type 2 socket"
        static let type2Plug = "Type 2 plug"
        static let type3a = "Type 3A"
        static let type3c = "Type 3C"
        static let ccsType2 = "CCS Type 2"
        static let ccsType1 = "CCS Type 1"
        static let ccsUnknown = "CCS (either Type 1 or Type 2)"
        static let schuko = "Schuko"
        static let chademo = "CHAdeMO"
        static let supercharger = "Tesla Supercharger"
        static let ceeBlau = "CEE Blau"
        static let ceeRot = "CEE Rot"
        static let teslaRoadsterHpc = "Tesla HPC"

        /// Asset-Name des Stecker-Symbols (Template-Bild aus Android `connectors/`).
        static func iconName(for type: String) -> String {
            switch type {
            case type1: return "connector_typ1"
            case type2Unknown, type2Socket, type2Plug, type3a, type3c: return "connector_typ2"
            case ccsType1: return "connector_ccs_typ1"
            case ccsType2, ccsUnknown: return "connector_ccs"
            case chademo: return "connector_chademo"
            case schuko: return "connector_schuko"
            case supercharger: return "connector_supercharger"
            case ceeBlau: return "connector_cee_blau"
            case ceeRot: return "connector_cee_rot"
            default: return "connector_unknown"
            }
        }

        /// Menschenlesbarer, lokalisierter Name für einen Steckertyp.
        static func displayName(for type: String) -> String {
            switch type {
            case type1: return String(localized: "Typ 1")
            case type2Unknown, type2Socket, type2Plug: return String(localized: "Typ 2")
            case type3a: return String(localized: "Typ 3A")
            case type3c: return String(localized: "Typ 3C")
            case ccsType1: return String(localized: "CCS Typ 1")
            case ccsType2: return String(localized: "CCS Typ 2")
            case ccsUnknown: return String(localized: "CCS")
            case schuko: return String(localized: "Schuko")
            case chademo: return String(localized: "CHAdeMO")
            case supercharger: return String(localized: "Tesla Supercharger")
            case ceeBlau: return String(localized: "CEE Blau")
            case ceeRot: return String(localized: "CEE Rot")
            case teslaRoadsterHpc: return String(localized: "Tesla HPC")
            default: return type
            }
        }
    }
}
