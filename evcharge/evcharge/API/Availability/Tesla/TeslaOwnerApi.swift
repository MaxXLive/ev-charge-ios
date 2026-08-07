//
//  TeslaOwnerApi.swift
//  evcharge
//
//  Charging-Ownership-GraphQL (Login erforderlich). Portiert aus
//  api/availability/tesla/TeslaOwnerApi.kt (TeslaChargingOwnershipGraphQlApi).
//

import Foundation

actor TeslaOwnerApi {
    private let session: URLSession
    private let baseURL = "https://akamai-apigateway-charging-ownership.tesla.com"
    private let coordRange = 0.005
    /// Liefert ein gültiges (ggf. erneuertes) Access-Token.
    private let tokenProvider: @Sendable () async throws -> String

    init(session: URLSession = .shared, tokenProvider: @escaping @Sendable () async throws -> String) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    /// Findet die nächstgelegene Tesla-Site und gibt deren `locationGUID` zurück.
    func nearestLocationGUID(lat: Double, lng: Double) async throws -> String {
        let variables: [String: Any] = [
            "args": [
                "userLocation": ["latitude": lat, "longitude": lng],
                "northwestCorner": ["latitude": lat + coordRange, "longitude": lng - coordRange],
                "southeastCorner": ["latitude": lat - coordRange, "longitude": lng + coordRange],
                "filters": [],
                "languageCode": "en",
                "countryCode": "US",
            ],
        ]
        let body: [String: Any] = [
            "operationName": "GetNearbyChargingSites",
            "query": TeslaGraphQLQueries.nearbyChargingSites,
            "variables": variables,
        ]
        let data = try await post(body: body, query: [
            .init(name: "operationName", value: "GetNearbyChargingSites"),
            .init(name: "deviceLanguage", value: "en"),
            .init(name: "deviceCountry", value: "US"),
            .init(name: "ttpLocale", value: "en_US"),
            .init(name: "vin", value: ""),
        ])
        let resp = try JSONDecoder().decode(OwnerNearbyResponse.self, from: data)
        guard let nearest = resp.data.charging?.nearbySites.sitesAndDistances
            .min(by: { $0.haversineDistanceMiles.value < $1.haversineDistanceMiles.value })
        else { throw AvailabilityError.noCandidate }
        return nearest.locationGUID
    }

    func siteInformation(locationGUID: String) async throws -> OwnerSiteInfoResponse.Site {
        let variables: [String: Any] = [
            "id": ["id": locationGUID, "type": "LOCATION_GUID"],
            "vehicleMakeType": "NON_TESLA",
            "deviceLanguage": "en",
            "deviceCountry": "US",
            "ttpLocale": "en_US",
        ]
        let body: [String: Any] = [
            "operationName": "getChargingSiteInformation",
            "query": TeslaGraphQLQueries.chargingSiteInformation,
            "variables": variables,
        ]
        let data = try await post(body: body, query: [
            .init(name: "operationName", value: "getChargingSiteInformation"),
            .init(name: "deviceLanguage", value: "en"),
            .init(name: "deviceCountry", value: "US"),
            .init(name: "ttpLocale", value: "en_US"),
            .init(name: "vin", value: ""),
        ])
        let resp = try JSONDecoder().decode(OwnerSiteInfoResponse.self, from: data)
        guard let site = resp.data.charging.site else { throw AvailabilityError.noCandidate }
        return site
    }

    private func post(body: [String: Any], query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(string: baseURL + "/graphql")!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        let token = try await tokenProvider()
        TeslaAuthApi.applyTeslaHeaders(&req, bearer: token)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AvailabilityError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}
