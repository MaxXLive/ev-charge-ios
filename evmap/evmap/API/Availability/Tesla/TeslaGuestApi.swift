//
//  TeslaGuestApi.swift
//  evmap
//
//  Tesla-Gast-APIs ohne Login (CUA-Standortliste + Guest-GraphQL). Portiert aus
//  api/availability/tesla/TeslaGuestApi.kt.
//

import Foundation

actor TeslaGuestApi {
    private let session: URLSession
    private let cuaBase = "https://www.tesla.com/cua-api"
    private let guestBase = "https://www.tesla.com/de_DE/charging/guest/api"

    enum Experience: String { case adhoc = "ADHOC", guest = "GUEST" }

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Liste aller Tesla-Standorte (groß, daher serverseitig cachebar).
    func locations() async throws -> [TeslaCuaLocation] {
        var comps = URLComponents(string: cuaBase + "/tesla-locations")!
        comps.queryItems = [
            .init(name: "translate", value: "en_US"),
            .init(name: "usetrt", value: "true"),
        ]
        var req = URLRequest(url: comps.url!)
        req.cachePolicy = .returnCacheDataElseLoad
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AvailabilityError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([TeslaCuaLocation].self, from: data)
    }

    /// Site-Details (Verfügbarkeit + Preise) für eine TRT-ID und Erfahrung (ADHOC/GUEST).
    func siteDetails(trtId: Int64, experience: Experience) async throws -> GuestSiteDetailsResponse.Site? {
        let variables: [String: Any] = [
            "siteId": [
                "byTrtId": [
                    "trtId": trtId,
                    "chargingExperience": experience.rawValue,
                    "programType": "PTSCH",
                    "locale": "de-DE",
                ],
            ],
        ]
        let body: [String: Any] = [
            "operationName": "GetSiteDetails",
            "query": TeslaGraphQLQueries.guestSiteDetails,
            "variables": variables,
        ]
        var comps = URLComponents(string: guestBase + "/graphql")!
        comps.queryItems = [.init(name: "operationName", value: "GetSiteDetails")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AvailabilityError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(GuestSiteDetailsResponse.self, from: data).data.chargingNetwork?.site
    }
}
