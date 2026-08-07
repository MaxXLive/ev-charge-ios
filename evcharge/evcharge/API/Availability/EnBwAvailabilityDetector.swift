//
//  EnBwAvailabilityDetector.swift
//  evcharge
//
//  Echtzeit-Verfügbarkeit über die öffentliche EnBW-EMP-API (Android-Pendant:
//  api/availability/EnBwAvailabilityDetector.kt). Vereinfachtes Matching.
//

import CoreLocation
import Foundation

actor EnBwAvailabilityDetector: AvailabilityDetector {
    private let session: URLSession
    private let baseURL = "https://enbw-emp.azure-api.net/emobility-public-api/api/v1"
    private let coordRange = 0.005
    private let maxRadius = 150.0   // m
    private let maxDistance = 60.0  // m zwischen zusammengehörigen Stationen

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - DTOs

    private struct Viewport: Decodable {
        let lowerLeftLat, lowerLeftLon, upperRightLat, upperRightLon: Double
    }
    private struct Marker: Decodable {
        let lat, lon: Double
        let stationId: Int64?
        let grouped: Bool
        let operatorName: String?
        let viewPort: Viewport
        enum CodingKeys: String, CodingKey {
            case lat, lon, stationId, grouped, viewPort
            case operatorName = "operator"
        }
    }
    private struct Connector: Decodable {
        let plugTypeName: String
        let maxPowerInKw: Double?
    }
    private struct State: Decodable { let updatedAt: Int64? }
    private struct ChargePoint: Decodable {
        let evseId: String?
        let status: String
        let connectors: [Connector]
        let state: State?
    }
    private struct LocationDetail: Decodable {
        let stationId: Int64
        let chargePoints: [ChargePoint]
    }

    // MARK: - Netzwerk

    private func request(_ path: String, query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.setValue(Secrets.enBwSubscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        req.setValue("https://www.enbw.com", forHTTPHeaderField: "Origin")
        req.setValue("https://www.enbw.com/", forHTTPHeaderField: "Referer")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // EnBW lokalisiert die Stecker-Namen nach Accept-Language. Deutsch erzwingen,
        // damit das Typ-Mapping unabhängig von der Geräte-Sprache funktioniert.
        req.setValue("de-DE", forHTTPHeaderField: "Accept-Language")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw AvailabilityError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    private func getMarkers(fromLon: Double, toLon: Double, fromLat: Double, toLat: Double) async throws -> [Marker] {
        let data = try await request("/chargestations", query: [
            URLQueryItem(name: "grouping", value: "false"),
            URLQueryItem(name: "fromLon", value: String(fromLon)),
            URLQueryItem(name: "toLon", value: String(toLon)),
            URLQueryItem(name: "fromLat", value: String(fromLat)),
            URLQueryItem(name: "toLat", value: String(toLat)),
        ])
        return try JSONDecoder().decode([Marker].self, from: data)
    }

    private func getDetail(_ id: Int64) async throws -> LocationDetail {
        let data = try await request("/chargestations/\(id)", query: [])
        return try JSONDecoder().decode(LocationDetail.self, from: data)
    }

    // MARK: - Verfügbarkeit

    func getAvailability(_ location: ChargeLocation) async throws -> ChargeLocationStatus {
        let lat = location.coordinates.lat
        let lng = location.coordinates.lng

        var markers = try await getMarkers(
            fromLon: lng - coordRange, toLon: lng + coordRange,
            fromLat: lat - coordRange, toLat: lat + coordRange
        )
        // Gruppierte Marker bis zu 3× auflösen.
        for _ in 0..<3 {
            if !markers.contains(where: { $0.grouped }) { break }
            markers = try await ungroup(markers)
        }

        guard let nearest = markers.min(by: {
            distance($0.lat, $0.lon, lat, lng) < distance($1.lat, $1.lon, lat, lng)
        }), distance(nearest.lat, nearest.lon, lat, lng) <= maxRadius else {
            throw AvailabilityError.noCandidate
        }

        // Nahe Stationen desselben Betreibers kombinieren.
        let chosen: [Marker]
        let nearbySameOperator = markers.filter {
            distance($0.lat, $0.lon, nearest.lat, nearest.lon) < maxDistance
                && $0.operatorName == nearest.operatorName && $0.stationId != nil
        }
        chosen = nearbySameOperator.isEmpty ? [nearest] : nearbySameOperator

        let details = try await withThrowingTaskGroup(of: LocationDetail?.self) { group -> [LocationDetail] in
            for id in chosen.compactMap(\.stationId) {
                group.addTask { try? await self.getDetail(id) }
            }
            var result: [LocationDetail] = []
            for try await d in group { if let d { result.append(d) } }
            return result
        }

        var lastChange: Date?
        let connectors: [(type: String, power: Double?, status: ChargepointStatus)] =
            details.flatMap(\.chargePoints).flatMap { cp -> [(String, Double?, ChargepointStatus)] in
                if let ms = cp.state?.updatedAt {
                    let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
                    if lastChange == nil || date > lastChange! { lastChange = date }
                }
                let status = Self.mapStatus(cp.status)
                return cp.connectors.map { (Self.mapType($0.plugTypeName), $0.maxPowerInKw, status) }
            }

        guard !connectors.isEmpty else { throw AvailabilityError.noMatch }

        let entries = AvailabilityMatcher.match(connectors: connectors, to: location.chargepointsMerged)
        return ChargeLocationStatus(source: "EnBW", entries: entries, lastChange: lastChange)
    }

    private func ungroup(_ markers: [Marker]) async throws -> [Marker] {
        var result: [Marker] = []
        for m in markers {
            if m.grouped {
                let sub = try await getMarkers(
                    fromLon: m.viewPort.lowerLeftLon, toLon: m.viewPort.upperRightLon,
                    fromLat: m.viewPort.lowerLeftLat, toLat: m.viewPort.upperRightLat
                )
                result.append(contentsOf: sub)
            } else {
                result.append(m)
            }
        }
        return result
    }

    private func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        CLLocation(latitude: lat1, longitude: lon1)
            .distance(from: CLLocation(latitude: lat2, longitude: lon2))
    }

    nonisolated private static func mapType(_ name: String) -> String {
        let C = Chargepoint.Connector.self
        switch name {
        case "Typ 3A": return C.type3a
        case "Typ 3C \"Scame\"": return C.type3c
        case "Typ 2": return C.type2Unknown
        case "Typ 1 Steckdose": return C.type1
        case "Steckdose(D)": return C.schuko
        case "CCS (Typ 1)": return C.ccsType1
        case "CCS (Typ 2)": return C.ccsType2
        case "CHAdeMO": return C.chademo
        default: return "unknown"
        }
    }

    nonisolated private static func mapStatus(_ s: String) -> ChargepointStatus {
        switch s {
        case "AVAILABLE": return .available
        case "OCCUPIED": return .charging
        case "UNAVAILABLE", "OUT_OF_SERVICE": return .faulted
        default: return .unknown
        }
    }

    // MARK: - Unterstützung

    nonisolated func isSupported(_ location: ChargeLocation) -> Bool {
        let country = location.chargepriceData?.country ?? location.address?.country
        let supported = [
            "Deutschland", "Österreich", "Schweiz", "Belgien", "Dänemark", "Frankreich",
            "Italien", "Kroatien", "Liechtenstein", "Luxemburg", "Niederlande", "Polen",
            "Schweden", "Slowakei", "Slowenien", "Spanien", "Tschechien",
        ]
        guard location.dataSource == "goingelectric" else { return false }
        return supported.contains(country ?? "") && location.network != "Tesla Supercharger"
    }
}
