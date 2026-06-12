//
//  DataSource.swift
//  evmap
//
//  Registry der Charger-Datenquellen. Aktuell ist nur GoingElectric implementiert;
//  die übrigen sind als Roadmap-Platzhalter gelistet und werden aktiviert, sobald die
//  jeweilige `ChargepointAPI`-Implementierung existiert.
//

import Foundation

enum DataSourceID: String, CaseIterable, Identifiable, Sendable {
    case goingElectric
    case openChargeMap
    case nobil
    case openStreetMap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .goingElectric: return "GoingElectric.de"
        case .openChargeMap: return "Open Charge Map"
        case .nobil: return "NOBIL"
        case .openStreetMap: return "OpenStreetMap"
        }
    }

    var subtitle: String {
        switch self {
        case .goingElectric:
            return String(localized: "Sehr gute Abdeckung in den deutschsprachigen Ländern. Beschreibungen in Deutsch. Von der Community gepflegt.")
        case .openChargeMap:
            return String(localized: "Weltweite Abdeckung mit hoher Qualität. Beschreibungen in Englisch oder Landessprache. Von der Community gepflegt und offizielle Verzeichnisse einiger Länder (z.B. Nordamerika, UK, Frankreich, Norwegen).")
        case .nobil:
            return String(localized: "Offizielles Verzeichnis in Schweden und Norwegen.")
        case .openStreetMap:
            return String(localized: "Experimentelle Unterstützung in EVMap, nicht alle Funktionen nutzbar.")
        }
    }

    /// Ob für diese Quelle bereits eine API-Implementierung existiert.
    var isAvailable: Bool {
        switch self {
        case .goingElectric: return true
        case .openChargeMap: return true
        case .nobil: return true
        default: return false
        }
    }

    /// Filter-Keys die diese Quelle unterstützt.
    var supportedFilterKeys: Set<String> {
        switch self {
        case .goingElectric:
            return ["freecharging", "freeparking", "open_247", "min_power", "connectors",
                    "min_connectors", "networks", "exclude_faults", "barrierfree", "chargecards", "categories"]
        case .openChargeMap:
            return ["min_power", "connectors", "min_connectors", "exclude_faults", "operators"]
        case .nobil:
            return ["freeparking", "open_247", "min_power", "connectors", "min_connectors", "accessibilities"]
        case .openStreetMap:
            return []
        }
    }

    /// Erzeugt die zugehörige API – oder nil, falls (noch) nicht implementiert.
    func makeAPI() -> (any ChargepointAPI)? {
        switch self {
        case .goingElectric:
            return GoingElectricAPI(apikey: Secrets.goingElectricKey)
        case .openChargeMap:
            return OpenChargeMapAPI(apikey: Secrets.openChargeMapKey)
        case .nobil:
            return NobilAPI(apikey: Secrets.nobilKey)
        default:
            return nil
        }
    }

    /// Gespeicherte Einzelauswahl (Legacy-Kompatibilität).
    static var selected: DataSourceID {
        let raw = UserDefaults.standard.string(forKey: "dataSource")
        return raw.flatMap(DataSourceID.init) ?? .goingElectric
    }

    /// Gespeicherte Mehrfachauswahl. Kommaseparierter String in UserDefaults ("dataSources").
    /// Fällt auf Legacy-Einzelwert ("dataSource") zurück wenn neu leer.
    static var selectedSet: Set<DataSourceID> {
        get {
            let raw = UserDefaults.standard.string(forKey: "dataSources") ?? ""
            let ids = raw.split(separator: ",").compactMap { DataSourceID(rawValue: String($0)) }
            if !ids.isEmpty { return Set(ids) }
            return [selected]
        }
        set {
            let ids = newValue.isEmpty ? [DataSourceID.goingElectric] : Array(newValue)
            UserDefaults.standard.set(ids.map(\.rawValue).joined(separator: ","), forKey: "dataSources")
            if let first = ids.first {
                UserDefaults.standard.set(first.rawValue, forKey: "dataSource")
            }
        }
    }
}
