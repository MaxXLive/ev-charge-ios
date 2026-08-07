//
//  TeslaApiModels.swift
//  evcharge
//
//  Datenmodelle für die (inoffiziellen) Tesla-Charging-APIs. Portiert aus
//  api/availability/tesla/{TeslaApiCommon,TeslaOwnerApi,TeslaGuestApi}.kt.
//

import Foundation

// MARK: - Preise (quellenübergreifend)

/// Tesla-Preisstruktur. `memberRates` = Tesla-Fahrzeuge & Abonnent:innen,
/// `userRates` = ohne Abo (andere Kund:innen).
struct TeslaPricing: Decodable, Hashable, Sendable {
    let memberRates: TeslaRates?
    let userRates: TeslaRates?
    let hasMembershipPricing: Bool?
    let hasMSPPricing: Bool?
    let canDisplayCombinedComparison: Bool?
}

struct TeslaRates: Decodable, Hashable, Sendable {
    let activePricebook: TeslaPricebook
}

struct TeslaPricebook: Decodable, Hashable, Sendable {
    let charging: TeslaPricebookDetails
    let parking: TeslaPricebookDetails?
}

struct TeslaPricebookDetails: Decodable, Hashable, Sendable {
    let currencyCode: String
    let rates: [Double]
    /// Maßeinheit: "kwh" oder "min".
    let uom: String
    let touRates: TeslaTouRates?
}

struct TeslaTouRates: Decodable, Hashable, Sendable {
    let enabled: Bool
    let activeRatesByTime: [TeslaActiveRatesByTime]
}

struct TeslaActiveRatesByTime: Decodable, Hashable, Sendable {
    /// "HH:mm" oder "HH:mm:ss" (Tesla liefert lokale Tageszeit).
    let startTime: String
    let endTime: String
    let rates: [Double]
}

/// Ein Stundenbalken des Auslastungs-Histogramms (0–23 Uhr, 0–100 %).
struct TeslaUtilizationBucket: Hashable, Sendable, Identifiable {
    let hour: Int
    let percent: Int
    var id: Int { hour }
}

// MARK: - Verfügbarkeitsstatus eines Tesla-Stalls

enum TeslaChargerAvailability: String, Decodable, Sendable {
    case available = "CHARGER_AVAILABILITY_AVAILABLE"
    case occupied = "CHARGER_AVAILABILITY_OCCUPIED"
    case down = "CHARGER_AVAILABILITY_DOWN"
    case unknown = "CHARGER_AVAILABILITY_UNKNOWN"

    var status: ChargepointStatus {
        switch self {
        case .available: return .available
        case .occupied: return .occupied
        case .down: return .faulted
        case .unknown: return .unknown
        }
    }
}

// MARK: - OAuth

struct TeslaOAuthResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int64
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct TeslaUserInfoResponse: Decodable, Sendable {
    let response: TeslaUserInfo
}

struct TeslaUserInfo: Decodable, Sendable {
    let email: String
}

// MARK: - Generische GraphQL-Hüllen

/// `{ "value": T }`
struct TeslaValue<T: Decodable & Sendable & Hashable>: Decodable, Sendable, Hashable {
    let value: T
}

/// `{ "text": String }`
struct TeslaText: Decodable, Sendable, Hashable {
    let text: String
}

// MARK: - Owner GraphQL: GetNearbyChargingSites

struct OwnerNearbyResponse: Decodable, Sendable {
    let data: DataField
    struct DataField: Decodable, Sendable {
        let charging: Charging?
    }
    struct Charging: Decodable, Sendable {
        let nearbySites: NearbySites
    }
    struct NearbySites: Decodable, Sendable {
        let sitesAndDistances: [Site]
    }
    struct Site: Decodable, Sendable {
        let locationGUID: String
        let haversineDistanceMiles: TeslaValue<Double>
    }
}

// MARK: - Owner GraphQL: getChargingSiteInformation

struct OwnerSiteInfoResponse: Decodable, Sendable {
    let data: DataField
    struct DataField: Decodable, Sendable { let charging: Charging }
    struct Charging: Decodable, Sendable { let site: Site? }

    struct Site: Decodable, Sendable {
        let siteDynamic: SiteDynamic
        let siteStatic: SiteStatic
        let pricing: TeslaPricing
        let congestionPriceHistogram: CongestionHistogram?
    }
    struct SiteDynamic: Decodable, Sendable {
        let chargerDetails: [ChargerDetail]
    }
    struct ChargerDetail: Decodable, Sendable {
        let availability: TeslaChargerAvailability
        let charger: ChargerId
    }
    struct ChargerId: Decodable, Sendable {
        let id: TeslaText
        let label: TeslaValue<String>?
    }
    struct SiteStatic: Decodable, Sendable {
        let chargers: [ChargerId]
    }
    struct CongestionHistogram: Decodable, Sendable {
        let data: [Double]
        let dataAttributes: [DataAttribute]
    }
    struct DataAttribute: Decodable, Sendable {
        let label: String   // "12AM", "1AM", …
    }
}

// MARK: - Guest GraphQL: GetSiteDetails

struct GuestSiteDetailsResponse: Decodable, Sendable {
    let data: DataField
    struct DataField: Decodable, Sendable { let chargingNetwork: Network? }
    struct Network: Decodable, Sendable { let site: Site? }
    struct Site: Decodable, Sendable {
        let chargerList: [ChargerDetail]
        let trtId: Int64
        let name: String
        let pricing: TeslaPricing?
    }
    struct ChargerDetail: Decodable, Sendable {
        let availability: TeslaChargerAvailability
        let label: String?
        let id: String
    }
}

// MARK: - CUA (Guest-Standortliste)

struct TeslaCuaLocation: Decodable, Sendable {
    let latitude: Double?
    let longitude: Double?
    let locationId: String
    let trtId: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, trtId
        case locationId = "location_id"
    }
}
