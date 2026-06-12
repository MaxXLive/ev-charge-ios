//
//  ChargepointAPI.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – api/ChargepointApi.kt
//  Quellenunabhängige Abstraktion über eine Charger-Datenquelle (v1: GoingElectric).
//

import Foundation

/// Markerprotokoll für quellenspezifische Referenzdaten (Stecker-/Netzwerk-/Ladekarten-Listen).
protocol ReferenceData: Sendable {}

/// Geografische Bounding-Box.
struct CoordinateBounds: Sendable, Equatable {
    let southwest: Coordinate
    let northeast: Coordinate
}

/// Ergebnis einer Charger-Abfrage.
struct ChargepointList: Sendable {
    let items: [ChargepointListItem]
    /// Ob alle Treffer geladen wurden (Paginierung abgeschlossen).
    let isComplete: Bool

    static let empty = ChargepointList(items: [], isComplete: true)
}

/// Eine Charger-Datenquelle.
protocol ChargepointAPI: Sendable {
    var name: String { get }
    var id: String { get }
    /// Maximale lokale Cache-Dauer in Sekunden.
    var cacheLimit: TimeInterval { get }
    /// Ob Backend-Abfragen unterstützt werden.
    var supportsOnlineQueries: Bool { get }
    /// Ob der komplette Datensatz heruntergeladen werden kann.
    var supportsFullDownload: Bool { get }

    /// Charger innerhalb geografischer Grenzen.
    func getChargepoints(
        referenceData: ReferenceData,
        bounds: CoordinateBounds,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList>

    /// Charger innerhalb eines Radius (km).
    func getChargepointsRadius(
        referenceData: ReferenceData,
        location: Coordinate,
        radius: Int,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList>

    /// Detaildaten einer Station.
    func getChargepointDetail(
        referenceData: ReferenceData,
        id: Int64
    ) async -> Resource<ChargeLocation>

    /// Referenzdaten (Stecker/Netzwerke/Ladekarten) laden.
    func getReferenceData() async -> Resource<ReferenceData>

    /// Verfügbare Filter für diese Quelle, abhängig von den Referenzdaten.
    func getFilters(referenceData: ReferenceData) -> [Filter]
}

// MARK: - Gemeinsame Hilfsfunktionen (api/Utils.kt + viewmodel/MapViewModel.kt)

/// Leistungsstufen für den Min.-Leistung-Slider (Index → kW).
let powerSteps: [Int] = [0, 2, 3, 7, 11, 22, 43, 50, 75, 100, 150, 200, 250, 300, 350]

func mapPower(_ index: Int) -> Int {
    guard index >= 0, index < powerSteps.count else { return 0 }
    return powerSteps[index]
}

func mapPowerInverse(_ power: Int) -> Int {
    powerSteps.enumerated()
        .min { abs($0.element - power) < abs($1.element - power) }?
        .offset ?? 0
}

/// Cluster-Distanz (px) je Zoomstufe, nil = kein serverseitiges Clustering.
func getClusterDistance(zoom: Double) -> Int? {
    switch zoom {
    case 0.0...7.0: return 100
    case 7.0...15.0: return 75
    default: return nil
    }
}

/// Äquivalente Steckertypen (z.B. CCS unbekannt deckt Typ 1 + Typ 2 ab).
nonisolated func equivalentPlugTypes(_ type: String) -> Set<String> {
    let C = Chargepoint.Connector.self
    switch type {
    case C.ccsType1: return [C.ccsUnknown, C.ccsType1]
    case C.ccsType2: return [C.ccsUnknown, C.ccsType2]
    case C.ccsUnknown: return [C.ccsUnknown, C.ccsType1, C.ccsType2]
    case C.type2Plug: return [C.type2Unknown, C.type2Plug]
    case C.type2Socket: return [C.type2Unknown, C.type2Socket]
    case C.type2Unknown: return [C.type2Unknown, C.type2Plug, C.type2Socket]
    default: return [type]
    }
}
