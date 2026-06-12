//
//  GoingElectricAPI.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – api/goingelectric/GoingElectricApi.kt
//

import Foundation

actor GoingElectricAPI: ChargepointAPI {
    nonisolated let name = "GoingElectric.de"
    nonisolated let id = "goingelectric"
    nonisolated let cacheLimit: TimeInterval = 24 * 60 * 60 // 1 Tag
    nonisolated let supportsOnlineQueries = true
    nonisolated let supportsFullDownload = false

    private let apikey: String
    private let baseURL: String
    private let session: URLSession

    init(apikey: String, baseURL: String = "https://api.goingelectric.de", session: URLSession = .shared) {
        self.apikey = apikey
        self.baseURL = baseURL
        self.session = session
    }

    private static let statusOK = "ok"

    // MARK: - Netzwerk-Helfer

    private enum APIError: Error { case http(Int), badStatus(String), decoding(Error) }

    private func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    /// Form-encoded POST mit API-Key als Query-Parameter.
    private func postForm(path: String, fields: [(String, String?)]) async throws -> Data {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = [URLQueryItem(name: "key", value: apikey)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = fields
            .compactMap { key, value in value.map { "\(key)=\(percentEncoded($0))" } }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        guard http.statusCode == 200 else { throw APIError.http(http.statusCode) }
        return data
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = [URLQueryItem(name: "key", value: apikey)] + query
        let (data, resp) = try await session.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        guard http.statusCode == 200 else { throw APIError.http(http.statusCode) }
        return data
    }

    // MARK: - Filter-Parameter

    private func formatMultipleChoice(_ value: (values: Set<String>, all: Bool)?) -> String? {
        guard let value, !value.all else { return nil }
        return value.values.sorted().joined(separator: ",")
    }

    /// Baut die Filter-bezogenen Formularfelder. Gibt nil zurück, wenn eine Mehrfachauswahl leer
    /// (und nicht „alle") ist – dann ist das Ergebnis garantiert leer.
    private func filterFields(_ filters: FilterValues?) -> [(String, String?)]? {
        let freecharging = filters?.booleanValue("freecharging") ?? false
        let freeparking = filters?.booleanValue("freeparking") ?? false
        let open247 = filters?.booleanValue("open_247") ?? false
        let barrierfree = filters?.booleanValue("barrierfree") ?? false
        let excludeFaults = filters?.booleanValue("exclude_faults") ?? false
        let minPower = filters?.sliderValue("min_power") ?? 0

        typealias Choice = (values: Set<String>, all: Bool)
        enum ChoiceResult { case empty; case value(Choice?) }
        func choice(_ key: String) -> ChoiceResult {
            guard let v = filters?.multipleChoiceValue(key) else { return .value(nil) }
            if v.values.isEmpty && !v.all { return .empty } // leere Auswahl -> Ergebnis leer
            return .value(v)
        }

        guard case let .value(connectorsVal0) = choice("connectors") else { return nil }
        var connectorsVal = connectorsVal0
        // Tesla-Supercharger-CCS-Sonderfall (siehe getFilters).
        if var cv = connectorsVal, cv.values.contains("CCS") {
            cv.values.insert("Tesla Supercharger CCS")
            connectorsVal = cv
        }

        guard case let .value(chargeCardsVal) = choice("chargecards") else { return nil }
        guard case let .value(networksVal) = choice("networks") else { return nil }
        guard case let .value(categoriesVal) = choice("categories") else { return nil }

        return [
            ("freecharging", String(freecharging)),
            ("freeparking", String(freeparking)),
            ("open_twentyfourseven", String(open247)),
            ("barrierfree", String(barrierfree)),
            ("exclude_faults", String(excludeFaults)),
            ("min_power", String(minPower)),
            ("plugs", formatMultipleChoice(connectorsVal)),
            ("chargecards", formatMultipleChoice(chargeCardsVal)),
            ("networks", formatMultipleChoice(networksVal)),
            ("categories", formatMultipleChoice(categoriesVal)),
        ]
    }

    // MARK: - Charger-Abfragen

    func getChargepoints(
        referenceData: ReferenceData,
        bounds: CoordinateBounds,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        guard let filterParams = filterFields(filters) else {
            return .success(.empty)
        }
        let minConnectors = filters?.sliderValue("min_connectors")
        let geClusteringAvailable = (minConnectors ?? 0) <= 1
        let useGeClustering = useClustering && geClusteringAvailable
        let clusterDistance = useClustering ? getClusterDistance(zoom: zoom) : nil

        let baseFields: [(String, String?)] = [
            ("sw_lat", String(bounds.southwest.lat)),
            ("sw_lng", String(bounds.southwest.lng)),
            ("ne_lat", String(bounds.northeast.lat)),
            ("ne_lng", String(bounds.northeast.lng)),
            ("zoom", String(zoom)),
            ("clustering", String(useGeClustering)),
            ("cluster_distance", clusterDistance.map(String.init)),
        ]
        return await loadPaged(baseFields: baseFields + filterParams, filters: filters)
    }

    func getChargepointsRadius(
        referenceData: ReferenceData,
        location: Coordinate,
        radius: Int,
        zoom: Double,
        useClustering: Bool,
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        guard let filterParams = filterFields(filters) else {
            return .success(.empty)
        }
        let minConnectors = filters?.sliderValue("min_connectors")
        let geClusteringAvailable = (minConnectors ?? 0) <= 1
        let useGeClustering = useClustering && geClusteringAvailable
        let clusterDistance = useClustering ? getClusterDistance(zoom: zoom) : nil

        let baseFields: [(String, String?)] = [
            ("lat", String(location.lat)),
            ("lng", String(location.lng)),
            ("radius", String(radius)),
            ("orderby", "distance"),
            ("zoom", String(zoom)),
            ("clustering", String(useGeClustering)),
            ("cluster_distance", clusterDistance.map(String.init)),
        ]
        return await loadPaged(baseFields: baseFields + filterParams, filters: filters)
    }

    /// Lädt alle Seiten (Paginierung über `startkey`) und filtert lokal nach.
    private func loadPaged(
        baseFields: [(String, String?)],
        filters: FilterValues?
    ) async -> Resource<ChargepointList> {
        var startkey: Int? = nil
        var data: [GEListItem] = []
        repeat {
            do {
                let fields = baseFields + [("startkey", startkey.map(String.init))]
                let raw = try await postForm(path: "/chargepoints/", fields: fields)
                let body = try JSONDecoder().decode(GEChargepointList.self, from: raw)
                guard body.status == Self.statusOK else {
                    return .error("Status: \(body.status)", nil)
                }
                data.append(contentsOf: body.chargelocations ?? [])
                startkey = body.startkey
            } catch {
                return .error(errorMessage(error), nil)
            }
        } while startkey != nil && startkey! < 10000

        let result = postprocess(data, filters: filters)
        return .success(ChargepointList(items: result, isComplete: startkey == nil))
    }

    /// Wendet Filter an, die GE nicht nativ unterstützt (min_connectors), und konvertiert ins
    /// Domain-Modell. (Hinweis: kosmetisches „Inferring" von cost/openinghours/barrierfree aus
    /// aktiven Filtern wie im Android-Original ist noch nicht portiert – Detailabruf liefert die
    /// echten Werte.)
    private func postprocess(_ items: [GEListItem], filters: FilterValues?) -> [ChargepointListItem] {
        let minPower = filters?.sliderValue("min_power") ?? 0
        let minConnectors = filters?.sliderValue("min_connectors") ?? 0
        let connectorsVal = filters?.multipleChoiceValue("connectors")

        return items.filter { item in
            guard case let .location(loc) = item else { return true } // Cluster durchreichen
            let matching = loc.chargepoints
                .filter { Double($0.power) >= Double(minPower) }
                .filter { cp in
                    if let cv = connectorsVal, !cv.all { return cv.values.contains(cp.type) }
                    return true
                }
                .reduce(0) { $0 + $1.count }
            return matching >= minConnectors
        }.map { $0.convert(apikey: apikey, isDetailed: false) }
    }

    // MARK: - Detail

    func getChargepointDetail(referenceData: ReferenceData, id: Int64) async -> Resource<ChargeLocation> {
        do {
            let raw = try await get(path: "/chargepoints/", query: [URLQueryItem(name: "ge_id", value: String(id))])
            let body = try JSONDecoder().decode(GEChargepointList.self, from: raw)
            guard body.status == Self.statusOK,
                  let items = body.chargelocations, items.count == 1,
                  case let .location(loc) = items[0] else {
                return .error("Ungültige Antwort", nil)
            }
            return .success(loc.convert(apikey: apikey, isDetailed: true))
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    // MARK: - Referenzdaten

    func getReferenceData() async -> Resource<ReferenceData> {
        do {
            async let plugsRaw = get(path: "/chargepoints/pluglist/")
            async let networksRaw = get(path: "/chargepoints/networklist/")
            async let cardsRaw = get(path: "/chargepoints/chargecardlist/")

            let plugs = try JSONDecoder().decode(GEStringList.self, from: try await plugsRaw)
            let networks = try JSONDecoder().decode(GEStringList.self, from: try await networksRaw)
            let cards = try JSONDecoder().decode(GEChargeCardList.self, from: try await cardsRaw)

            guard plugs.status == Self.statusOK, networks.status == Self.statusOK, cards.status == Self.statusOK,
                  let p = plugs.result, let n = networks.result, let c = cards.result else {
                return .error("Referenzdaten unvollständig", nil)
            }
            return .success(GEReferenceData(plugs: p, networks: n, chargecards: c))
        } catch {
            return .error(errorMessage(error), nil)
        }
    }

    // MARK: - Filter-Definitionen

    nonisolated func getFilters(referenceData: ReferenceData) -> [Filter] {
        guard let refData = referenceData as? GEReferenceData else { return [] }

        // Plug-Auswahl: GE-Name -> Anzeigename. "Tesla Supercharger CCS" wird ausgeblendet,
        // da die API im Detail nur "CCS" zurückgibt (nicht lokal filterbar).
        var plugMap: [String: String] = [:]
        for plug in refData.plugs where plug != "Tesla Supercharger CCS" {
            plugMap[plug] = Chargepoint.Connector.displayName(for: GEChargepoint.convertTypeFromGE(plug))
        }
        let networkMap = Dictionary(uniqueKeysWithValues: refData.networks.map { ($0, $0) })
        let chargecardMap = Dictionary(uniqueKeysWithValues: refData.chargecards.map { (String($0.id), $0.name) })

        let categoryMap: [String: String] = [
            "Autohaus": "Autohaus", "Autobahnraststätte": "Autobahnraststätte",
            "Autohof": "Autohof", "Bahnhof": "Bahnhof", "Behörde": "Behörde",
            "Campingplatz": "Campingplatz", "Einkaufszentrum": "Einkaufszentrum",
            "Ferienwohnung": "Ferienwohnung", "Flughafen": "Flughafen",
            "Freizeitpark": "Freizeitpark", "Hotel": "Hotel", "Kino": "Kino",
            "Kirche": "Kirche", "Krankenhaus": "Krankenhaus", "Museum": "Museum",
            "Parkhaus": "Parkhaus", "Parkplatz": "Parkplatz",
            "Privater Ladepunkt": "Privater Ladepunkt", "Rastplatz": "Rastplatz",
            "Restaurant": "Restaurant", "Schwimmbad": "Schwimmbad",
            "Supermarkt": "Supermarkt", "Tankstelle": "Tankstelle",
            "Tiefgarage": "Tiefgarage", "Tierpark": "Tierpark",
            "Wohnmobilstellplatz": "Wohnmobilstellplatz",
        ]

        let commonConnectors = Set(
            [Chargepoint.Connector.type2Unknown,
             Chargepoint.Connector.ccsUnknown,
             Chargepoint.Connector.chademo]
            .compactMap { GEChargepoint.convertTypeToGE($0) }
        )

        return [
            .boolean(key: "freecharging", name: "Kostenloses Laden"),
            .boolean(key: "freeparking", name: "Kostenloses Parken"),
            .boolean(key: "open_247", name: "24/7 geöffnet"),
            .slider(key: "min_power", name: "Min. Leistung", min: 0, max: powerSteps.count - 1, steps: powerSteps, unit: "kW"),
            .multipleChoice(key: "connectors", name: "Steckertypen", choices: plugMap, commonChoices: commonConnectors, manyChoices: true),
            .slider(key: "min_connectors", name: "Min. Anzahl Ladepunkte", min: 1, max: 10, steps: nil, unit: nil),
            .multipleChoice(key: "networks", name: "Netzwerke", choices: networkMap, commonChoices: nil, manyChoices: true),
            .boolean(key: "exclude_faults", name: "Defekte ausblenden"),
            .boolean(key: "barrierfree", name: "Frei zugänglich"),
            .multipleChoice(key: "chargecards", name: "Ladekarten", choices: chargecardMap, commonChoices: nil, manyChoices: true),
            .multipleChoice(key: "categories", name: "Kategorien", choices: categoryMap, commonChoices: nil, manyChoices: true),
        ]
    }

    // MARK: -

    nonisolated private func errorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case let .http(code) where code == 401 || code == 403 || code == 429:
                return "API-Key fehlt, ist ungültig oder das Limit ist erreicht."
            case let .http(code):
                return "Serverfehler (HTTP \(code))."
            case let .badStatus(status):
                return "Unerwarteter Status: \(status)."
            case .decoding:
                return "Antwort konnte nicht gelesen werden."
            }
        }
        if let urlError = error as? URLError { return urlError.localizedDescription }
        return String(describing: error)
    }
}
