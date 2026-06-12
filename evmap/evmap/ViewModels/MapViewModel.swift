//
//  MapViewModel.swift
//  evmap
//
//  Portiert (sinngemäß) aus EVMap (Android, MIT) – viewmodel/MapViewModel.kt
//

import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class MapViewModel {
    private var apis: [any ChargepointAPI]
    private let availabilityService = AvailabilityService()

    /// Aktuell geladene Charger (oder Cluster).
    var chargers: Resource<ChargepointList> = .success(.empty)
    /// Referenzdaten je API-ID.
    var referenceDataMap: [String: ReferenceData] = [:]
    /// Aktive Filter (von der Filter-Ansicht gesetzt). nil = keine.
    var filters: FilterValues?
    /// Aktuell ausgewählte Station (öffnet Detail-Sheet).
    var selected: ChargeLocation?

    private var loadTask: Task<Void, Never>?
    /// Wird bei Filteränderung erhöht, damit die Karte neu lädt.
    var filterVersion = 0

    init(apis: [any ChargepointAPI]? = nil) {
        self.apis = apis ?? Self.makeAPIs(for: DataSourceID.selectedSet)
    }

    private static func makeAPIs(for sources: Set<DataSourceID>) -> [any ChargepointAPI] {
        let result = sources.compactMap { $0.makeAPI() }
        return result.isEmpty ? [GoingElectricAPI(apikey: Secrets.goingElectricKey)] : result
    }

    /// APIs neu setzen wenn Datenquellenauswahl geändert wurde.
    func updateAPIs() {
        apis = Self.makeAPIs(for: DataSourceID.selectedSet)
        referenceDataMap = [:]
        filterVersion += 1
    }

    var apiName: String { apis.map(\.name).joined(separator: ", ") }

    /// Erster API der zur dataSource einer Station passt.
    private func api(for dataSource: String) -> (any ChargepointAPI)? {
        apis.first { $0.id == dataSource }
    }

    /// Referenzdaten der primären Quelle (für Filter-Definitionen etc.).
    var referenceData: ReferenceData? { referenceDataMap[apis.first?.id ?? ""] }

    // MARK: - Filter

    /// Alle Filter aller aktiven Quellen (Union). Reihenfolge: erste Quelle zuerst, dann neue Keys.
    var availableFilters: [Filter] {
        guard !apis.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [Filter] = []
        for api in apis {
            guard let rd = referenceDataMap[api.id] else { continue }
            for filter in api.getFilters(referenceData: rd) {
                if seen.insert(filter.key).inserted { result.append(filter) }
            }
        }
        return result
    }

    /// Keys die von mindestens einer, aber nicht allen aktiven Quellen nicht unterstützt werden.
    /// Wert = Anzeigenamen der Quellen die diesen Key NICHT kennen.
    var partiallyUnsupportedFilters: [String: [String]] {
        guard apis.count > 1 else { return [:] }
        let activeSources = DataSourceID.selectedSet
        var result: [String: [String]] = [:]
        for filter in availableFilters {
            let missing = activeSources
                .filter { !$0.supportedFilterKeys.contains(filter.key) }
                .map { $0.displayName }
                .sorted()
            if !missing.isEmpty { result[filter.key] = missing }
        }
        return result
    }

    /// Aktuelle Filterwerte (mit Defaults aufgefüllt) zum Bearbeiten.
    func currentFilterValues() -> FilterValues {
        availableFilters.map { f in
            let value = filters?.first { $0.value.key == f.key }?.value ?? f.defaultValue
            return FilterWithValue(filter: f, value: value)
        }
    }

    /// Anzahl der von den Defaults abweichenden Filter.
    var activeFilterCount: Int {
        guard let filters else { return 0 }
        return filters.filter { !$0.value.hasSameValue(as: $0.filter.defaultValue) }.count
    }

    /// Filter anwenden (nil, wenn alles auf Default) und Neuladen anstoßen.
    func applyFilters(_ values: FilterValues) {
        let hasNonDefault = values.contains { !$0.value.hasSameValue(as: $0.filter.defaultValue) }
        filters = hasNonDefault ? values : nil
        filterVersion += 1
    }

    /// Werte aus einem gespeicherten Profil übernehmen.
    func applyProfileValues(_ profileValues: [FilterValue]) {
        let merged: FilterValues = availableFilters.map { f in
            let value = profileValues.first { $0.key == f.key } ?? f.defaultValue
            return FilterWithValue(filter: f, value: value)
        }
        applyFilters(merged)
    }

    func resetFilters() {
        filters = nil
        filterVersion += 1
    }

    func loadReferenceDataIfNeeded() async {
        await withTaskGroup(of: (String, ReferenceData)?.self) { group in
            for api in apis where referenceDataMap[api.id] == nil {
                group.addTask {
                    if case let .success(rd) = await api.getReferenceData() {
                        return (api.id, rd)
                    }
                    return nil
                }
            }
            for await result in group {
                if let (id, rd) = result {
                    referenceDataMap[id] = rd
                }
            }
        }
    }

    /// Wird bei Kamerabewegung aufgerufen; lädt nach kurzer Verzögerung (Debounce) neu.
    func onRegionChange(_ region: MKCoordinateRegion) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.load(region: region)
        }
    }

    /// Erneut laden (z.B. nach Filteränderung) für die zuletzt gesehene Region.
    func reload(region: MKCoordinateRegion) {
        onRegionChange(region)
    }

    private func load(region: MKCoordinateRegion) async {
        let bounds = region.coordinateBounds
        let zoom = region.zoomLevel
        chargers = .loading(chargers.value)
        await loadReferenceDataIfNeeded()

        let useClustering = zoom < 15
        let currentFilters = filters

        // Alle APIs parallel abfragen.
        var allItems: [ChargepointListItem] = []
        var firstError: String? = nil

        await withTaskGroup(of: Resource<ChargepointList>.self) { group in
            for api in apis {
                guard let rd = referenceDataMap[api.id] else { continue }
                group.addTask {
                    await api.getChargepoints(
                        referenceData: rd,
                        bounds: bounds,
                        zoom: zoom,
                        useClustering: useClustering,
                        filters: currentFilters
                    )
                }
            }
            for await result in group {
                switch result {
                case let .success(list):
                    allItems.append(contentsOf: list.items)
                case let .error(msg, partial):
                    if firstError == nil { firstError = msg }
                    if let partial { allItems.append(contentsOf: partial.items) }
                default: break
                }
            }
        }

        guard !Task.isCancelled else { return }

        if allItems.isEmpty, let err = firstError {
            chargers = .error(err, nil)
            return
        }

        // Deduplizieren (gleiche stableId).
        var seen = Set<String>()
        let deduped = allItems.filter { item in
            if case let .location(loc) = item {
                return seen.insert(loc.stableId).inserted
            }
            return true
        }

        let merged = ChargepointList(items: deduped, isComplete: true)
        if useClustering {
            chargers = .success(clientCluster(merged, zoom: zoom))
        } else {
            chargers = .success(merged)
        }
    }

    /// Client-seitiges Grid-Clustering für Locations ohne Server-Clustering (OCM, Nobil).
    /// Server-Cluster (GE) werden unverändert übernommen.
    private func clientCluster(_ list: ChargepointList, zoom: Double) -> ChargepointList {
        // Server-Cluster direkt übernehmen, nur Locations clustern.
        let serverClusters = list.items.filter { if case .cluster = $0 { return true }; return false }

        // Zellgröße in Grad: bei Zoom 7 ≈ 0.5°, bei Zoom 14 ≈ 0.004° (halbiert sich pro Zoomstufe).
        let cellSize = 64.0 / pow(2.0, zoom)
        var cells: [String: [ChargeLocation]] = [:]
        for item in list.items {
            guard case let .location(loc) = item else { continue }
            let col = Int(floor(loc.coordinates.lat / cellSize))
            let row = Int(floor(loc.coordinates.lng / cellSize))
            cells["\(col):\(row)", default: []].append(loc)
        }

        let clustered: [ChargepointListItem] = cells.values.map { group in
            guard group.count > 1 else { return .location(group[0]) }
            let avgLat = group.map(\.coordinates.lat).reduce(0, +) / Double(group.count)
            let avgLng = group.map(\.coordinates.lng).reduce(0, +) / Double(group.count)
            return .cluster(ChargeLocationCluster(
                clusterCount: group.count,
                coordinates: Coordinate(lat: avgLat, lng: avgLng),
                items: group
            ))
        }
        return ChargepointList(items: serverClusters + clustered, isComplete: list.isComplete)
    }

    /// Detaildaten der ausgewählten Station nachladen (via passender API für dataSource).
    func loadDetail(for location: ChargeLocation) async -> ChargeLocation? {
        guard let api = api(for: location.dataSource),
              let rd = referenceDataMap[api.id] else { return nil }
        if case let .success(detailed) = await api.getChargepointDetail(referenceData: rd, id: location.id) {
            return detailed
        }
        return nil
    }

    /// Echtzeit-Verfügbarkeit für eine Station (nil, wenn keine Quelle Daten hat).
    func loadAvailability(for location: ChargeLocation) async -> ChargeLocationStatus? {
        await availabilityService.availability(for: location)
    }
}

// MARK: - MapKit-Hilfen

extension MKCoordinateRegion {
    var coordinateBounds: CoordinateBounds {
        CoordinateBounds(
            southwest: Coordinate(
                lat: center.latitude - span.latitudeDelta / 2,
                lng: center.longitude - span.longitudeDelta / 2
            ),
            northeast: Coordinate(
                lat: center.latitude + span.latitudeDelta / 2,
                lng: center.longitude + span.longitudeDelta / 2
            )
        )
    }

    /// Näherung einer Web-Mercator-Zoomstufe aus der Längen-Spanne.
    var zoomLevel: Double {
        guard span.longitudeDelta > 0 else { return 16 }
        return max(0, log2(360 / span.longitudeDelta))
    }
}
