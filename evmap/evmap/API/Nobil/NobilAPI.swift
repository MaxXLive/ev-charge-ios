//
//  NobilAPI.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – api/nobil/NobilApi.kt
//  Nobil (Skandinavien) über Online-Rectangle-/Radius-Suche (search.php).
//  Kein Server-Clustering, keine serverseitigen Filter (alles lokal in convert()).
//

import Foundation

actor NobilAPI: ChargepointAPI {
    nonisolated let name = "Nobil"
    nonisolated let id = "nobil"
    nonisolated let cacheLimit: TimeInterval = 300 * 24 * 60 * 60
    nonisolated let supportsOnlineQueries = true
    nonisolated let supportsFullDownload = false

    private let apikey: String
    private let baseURL: String
    private let session: URLSession
    private let maxResults = 1000

    init(apikey: String, baseURL: String = "https://nobil.no/api/server", session: URLSession = .shared) {
        self.apikey = apikey
        self.baseURL = baseURL
        self.session = session
    }

    private enum APIError: Error { case http(Int), api(String) }

    private func search<Body: Encodable>(_ body: Body) async throws -> NobilResponseData {
        var req = URLRequest(url: URL(string: baseURL + "/search.php")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(NobilResponseData.self, from: data)
        if let error = decoded.error, !error.isEmpty { throw APIError.api(error) }
        return decoded
    }

    // MARK: - Abfragen

    func getChargepoints(
        referenceData: ReferenceData,
        bounds: CoordinateBounds,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        let ne = "(\(bounds.northeast.lat), \(bounds.northeast.lng))"
        let sw = "(\(bounds.southwest.lat), \(bounds.southwest.lng))"
        let request = NobilRectangleSearchRequest(apikey: apikey, northeast: ne, southwest: sw, limit: maxResults)
        return await load(filters: filters) { try await self.search(request) }
    }

    func getChargepointsRadius(
        referenceData: ReferenceData,
        location: Coordinate,
        radius: Int,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        let request = NobilRadiusSearchRequest(
            apikey: apikey, lat: location.lat, long: location.lng,
            distance: Double(radius) * 1000, limit: maxResults
        )
        return await load(filters: filters) { try await self.search(request) }
    }

    private func load(
        filters: FilterValues? = nil,
        _ fetch: () async throws -> NobilResponseData
    ) async -> Resource<ChargepointList> {
        do {
            let data = try await fetch()
            guard let stations = data.chargerStations else {
                return .success(.empty)
            }
            let license = data.rights ?? "© NOBIL.no, Creative Commons Attribution 4.0 International"
            var seen = Set<Int64>()
            let items: [ChargepointListItem] = stations.compactMap { station in
                guard let loc = station.convert(license: license, filters: filters) else { return nil }
                guard seen.insert(loc.id).inserted else { return nil }
                return .location(loc)
            }
            return .success(ChargepointList(items: items, isComplete: stations.count < maxResults))
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    func getChargepointDetail(referenceData: ReferenceData, id: Int64) async -> Resource<ChargeLocation> {
        // Nobil liefert Volldaten bereits in der Suche; ein separater Detail-Abruf per Long-ID
        // ist nicht möglich (IDs sind z.B. "SWE_1234").
        .error(String(localized: "Nicht unterstützt"), nil)
    }

    func getReferenceData() async -> Resource<ReferenceData> {
        .success(NobilReferenceData())
    }

    // MARK: - Filter

    nonisolated func getFilters(referenceData: ReferenceData) -> [Filter] {
        let C = Chargepoint.Connector.self
        let connectors = [C.type1, C.type2Socket, C.type2Plug, C.ccsUnknown, C.chademo, C.supercharger]
        let connectorMap = Dictionary(uniqueKeysWithValues: connectors.map { ($0, C.displayName(for: $0)) })
        // Keys sind feste Nobil-Werte (englisch), Anzeigewerte werden lokalisiert.
        let accessibilityMap: [String: String] = [
            "Public": String(localized: "Öffentlich"),
            "Visitors": String(localized: "Besucher"),
            "Employees": String(localized: "Mitarbeiter"),
            "By appointment": String(localized: "Nach Vereinbarung"),
            "Residents": String(localized: "Anwohner"),
        ]
        return [
            .boolean(key: "freeparking", name: String(localized: "Kostenloses Parken")),
            .boolean(key: "open_247", name: String(localized: "24/7 geöffnet")),
            .slider(key: "min_power", name: String(localized: "Min. Leistung"), min: 0, max: powerSteps.count - 1, steps: powerSteps, unit: "kW"),
            .multipleChoice(key: "connectors", name: String(localized: "Steckertypen"), choices: connectorMap, commonChoices: nil, manyChoices: true),
            .slider(key: "min_connectors", name: String(localized: "Min. Anzahl Ladepunkte"), min: 1, max: 10, steps: nil, unit: nil),
            .multipleChoice(key: "accessibilities", name: String(localized: "Zugänglichkeit"), choices: accessibilityMap, commonChoices: nil, manyChoices: true),
        ]
    }

    nonisolated private func errorMessage(_ error: Error) -> String {
        if let e = error as? APIError {
            switch e {
            case let .http(code): return String(localized: "Serverfehler (HTTP \(code)).")
            case let .api(msg): return msg
            }
        }
        if let urlError = error as? URLError { return urlError.localizedDescription }
        return String(localized: "Antwort konnte nicht gelesen werden.")
    }
}
