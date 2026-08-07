//
//  OpenChargeMapAPI.swift
//  evcharge
//
//  Portiert aus EVMap (Android, MIT) – api/openchargemap/OpenChargeMapApi.kt
//  Open Charge Map kennt kein serverseitiges Clustering; es werden einzelne POIs geliefert.
//

import Foundation

actor OpenChargeMapAPI: ChargepointAPI {
    nonisolated let name = "Open Charge Map"
    nonisolated let id = "openchargemap"
    nonisolated let cacheLimit: TimeInterval = 300 * 24 * 60 * 60
    nonisolated let supportsOnlineQueries = true
    nonisolated let supportsFullDownload = false

    private let apikey: String
    private let baseURL: String
    private let session: URLSession
    private let maxResults = 500

    init(apikey: String, baseURL: String = "https://api.openchargemap.io/v3", session: URLSession = .shared) {
        self.apikey = apikey
        self.baseURL = baseURL
        self.session = session
    }

    private enum APIError: Error { case http(Int) }

    private func get(path: String, query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.setValue(apikey, forHTTPHeaderField: "X-API-Key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    // MARK: - Filter

    private func formatMultipleChoice(_ value: (values: Set<String>, all: Bool)?) -> String? {
        guard let value, !value.all else { return nil }
        return value.values.sorted().joined(separator: ",")
    }

    private enum FilterQuery { case empty; case items([URLQueryItem]) }

    /// Baut Filter-Query-Items; `.empty` wenn eine Mehrfachauswahl leer (Ergebnis garantiert leer).
    private func filterQuery(_ filters: FilterValues?) -> FilterQuery {
        let minPower = filters?.sliderValue("min_power")

        // empty = leere Auswahl (Ergebnis leer), value = Auswahl (oder nil, wenn Filter nicht gesetzt).
        func resolve(_ key: String) -> (empty: Bool, value: (values: Set<String>, all: Bool)?) {
            guard let v = filters?.multipleChoiceValue(key) else { return (false, nil) }
            if v.values.isEmpty && !v.all { return (true, nil) }
            return (false, v)
        }

        let conn = resolve("connectors")
        let ops = resolve("operators")
        if conn.empty || ops.empty { return .empty }

        var items: [URLQueryItem] = []
        if let mp = minPower, mp > 0 { items.append(URLQueryItem(name: "minpowerkw", value: String(mp))) }
        if let c = formatMultipleChoice(conn.value) { items.append(URLQueryItem(name: "connectiontypeid", value: c)) }
        if let o = formatMultipleChoice(ops.value) { items.append(URLQueryItem(name: "operatorid", value: o)) }
        return .items(items)
    }

    // MARK: - Abfragen

    func getChargepoints(
        referenceData: ReferenceData,
        bounds: CoordinateBounds,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        guard case let .items(extra) = filterQuery(filters) else { return .success(.empty) }
        let box = "(\(bounds.southwest.lat),\(bounds.southwest.lng)),(\(bounds.northeast.lat),\(bounds.northeast.lng))"
        let query = [
            URLQueryItem(name: "boundingbox", value: box),
            URLQueryItem(name: "maxresults", value: String(maxResults)),
            URLQueryItem(name: "compact", value: "true"),
            URLQueryItem(name: "verbose", value: "false"),
        ] + extra
        return await load(query: query, filters: filters, referenceData: referenceData)
    }

    func getChargepointsRadius(
        referenceData: ReferenceData,
        location: Coordinate,
        radius: Int,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        guard case let .items(extra) = filterQuery(filters) else { return .success(.empty) }
        let query = [
            URLQueryItem(name: "latitude", value: String(location.lat)),
            URLQueryItem(name: "longitude", value: String(location.lng)),
            URLQueryItem(name: "distance", value: String(radius)),
            URLQueryItem(name: "distanceunit", value: "KM"),
            URLQueryItem(name: "maxresults", value: String(maxResults)),
            URLQueryItem(name: "compact", value: "true"),
            URLQueryItem(name: "verbose", value: "false"),
        ] + extra
        return await load(query: query, filters: filters, referenceData: referenceData)
    }

    private func load(
        query: [URLQueryItem],
        filters: FilterValues?,
        referenceData: ReferenceData
    ) async -> Resource<ChargepointList> {
        guard let refData = referenceData as? OCMReferenceData else {
            return .error(String(localized: "Referenzdaten fehlen"), nil)
        }
        do {
            let data = try await get(path: "/poi/", query: query)
            let pois = try JSONDecoder().decode([OCMChargepoint].self, from: data)
            let items = postprocess(pois, filters: filters, refData: refData)
            return .success(ChargepointList(items: items, isComplete: pois.count < maxResults))
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    private func postprocess(
        _ pois: [OCMChargepoint],
        filters: FilterValues?,
        refData: OCMReferenceData
    ) -> [ChargepointListItem] {
        let minPower = Double(filters?.sliderValue("min_power") ?? 0)
        let minConnectors = filters?.sliderValue("min_connectors") ?? 0
        let connectorsVal = filters?.multipleChoiceValue("connectors")
        let excludeFaults = filters?.booleanValue("exclude_faults") ?? false

        return pois.filter { poi in
            // lokale Filter, die OCM nicht nativ unterstützt
            let matching = poi.connections
                .filter { ($0.power ?? 0) >= minPower || $0.power == nil }
                .filter { conn in
                    if let cv = connectorsVal, !cv.all {
                        return cv.values.contains(String(conn.connectionTypeId))
                    }
                    return true
                }
                .reduce(0) { $0 + ($1.quantity ?? 1) }
            return matching >= minConnectors
        }
        .filter { !$0.isRemoved && (!excludeFaults || !$0.hasFault) }
        .map { .location($0.convert(refData: refData, isDetailed: false)) }
    }

    func getChargepointDetail(referenceData: ReferenceData, id: Int64) async -> Resource<ChargeLocation> {
        guard let refData = referenceData as? OCMReferenceData else {
            return .error(String(localized: "Referenzdaten fehlen"), nil)
        }
        do {
            let data = try await get(path: "/poi/", query: [
                URLQueryItem(name: "chargepointid", value: String(id)),
                URLQueryItem(name: "includecomments", value: "true"),
                URLQueryItem(name: "compact", value: "false"),
                URLQueryItem(name: "verbose", value: "false"),
            ])
            let pois = try JSONDecoder().decode([OCMChargepoint].self, from: data)
            guard let poi = pois.first else { return .error(String(localized: "Nicht gefunden"), nil) }
            return .success(poi.convert(refData: refData, isDetailed: true))
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    func getReferenceData() async -> Resource<ReferenceData> {
        do {
            let data = try await get(path: "/referencedata/", query: [])
            let ref = try JSONDecoder().decode(OCMReferenceData.self, from: data)
            return .success(ref)
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    // MARK: - Filter-Definitionen

    nonisolated func getFilters(referenceData: ReferenceData) -> [Filter] {
        guard let refData = referenceData as? OCMReferenceData else { return [] }
        let plugMap = Dictionary(uniqueKeysWithValues: refData.connectionTypes.map { (String($0.id), $0.title) })
        let operatorMap = Dictionary(refData.operators.map { (String($0.id), $0.title) }, uniquingKeysWith: { a, _ in a })
        let commonConnectors: Set<String> = ["1", "25", "1036", "32", "33", "2"]

        return [
            .slider(key: "min_power", name: String(localized: "Min. Leistung"), min: 0, max: powerSteps.count - 1, steps: powerSteps, unit: "kW"),
            .multipleChoice(key: "connectors", name: String(localized: "Steckertypen"), choices: plugMap, commonChoices: commonConnectors, manyChoices: true),
            .multipleChoice(key: "operators", name: String(localized: "Betreiber"), choices: operatorMap, commonChoices: nil, manyChoices: true),
            .boolean(key: "exclude_faults", name: String(localized: "Defekte ausblenden")),
            .slider(key: "min_connectors", name: String(localized: "Min. Anzahl Ladepunkte"), min: 1, max: 10, steps: nil, unit: nil),
        ]
    }

    nonisolated private func errorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError, case let .http(code) = apiError {
            if code == 401 || code == 403 { return String(localized: "API-Key fehlt oder ist ungültig.") }
            return String(localized: "Serverfehler (HTTP \(code)).")
        }
        if let urlError = error as? URLError { return urlError.localizedDescription }
        return String(localized: "Antwort konnte nicht gelesen werden.")
    }
}
