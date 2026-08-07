//
//  GEModels.swift
//  evcharge
//
//  Portiert aus EVMap (Android, MIT) – api/goingelectric/GoingElectricModel.kt + GoingElectricAdapters.kt
//  GoingElectric-spezifische JSON-Modelle inkl. der „false statt null"-Eigenheiten,
//  plus Mapping auf das quellenunabhängige Domain-Modell.
//

import Foundation

// MARK: - Decode-Helfer für GE-Eigenheiten

/// GE liefert für „kein Wert" oft `false` statt `null`. Diese Helfer behandeln das,
/// indem ein fehlgeschlagener Decode (Bool statt erwartetem Typ) als nil interpretiert wird.
private extension KeyedDecodingContainer {
    func stringOrFalse(_ key: Key) -> String? {
        (try? decodeIfPresent(String.self, forKey: key)) ?? nil
    }

    func intOrFalse(_ key: Key) -> Int? {
        (try? decodeIfPresent(Int.self, forKey: key)) ?? nil
    }

    func listOrFalse<T: Decodable>(_ type: [T].Type, _ key: Key) -> [T]? {
        (try? decodeIfPresent([T].self, forKey: key)) ?? nil
    }
}

// MARK: - Top-Level-Antworten

struct GEChargepointList: Decodable {
    let status: String
    let chargelocations: [GEListItem]?
    let startkey: Int?

    enum CodingKeys: String, CodingKey { case status, chargelocations, startkey }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        chargelocations = try c.decodeIfPresent([GEListItem].self, forKey: .chargelocations)
        startkey = c.intOrFalse(.startkey)
    }
}

struct GEStringList: Decodable {
    let status: String
    let result: [String]?
}

struct GEChargeCardList: Decodable {
    let status: String
    let result: [GEChargeCard]?
}

// MARK: - Listen-Element (Standort oder Cluster)

enum GEListItem: Decodable {
    case location(GEChargeLocation)
    case cluster(GEChargeLocationCluster)

    private enum CodingKeys: String, CodingKey { case clustered }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let clustered = (try? c.decode(Bool.self, forKey: .clustered)) ?? false
        if clustered {
            self = .cluster(try GEChargeLocationCluster(from: decoder))
        } else {
            self = .location(try GEChargeLocation(from: decoder))
        }
    }

    func convert(apikey: String, isDetailed: Bool) -> ChargepointListItem {
        switch self {
        case let .location(loc): return .location(loc.convert(apikey: apikey, isDetailed: isDetailed))
        case let .cluster(cluster): return .cluster(cluster.convert())
        }
    }
}

struct GEChargeLocationCluster: Decodable {
    let clusterCount: Int
    let coordinates: GECoordinate

    func convert() -> ChargeLocationCluster {
        ChargeLocationCluster(clusterCount: clusterCount, coordinates: coordinates.convert())
    }
}

// MARK: - Ladestation

struct GEChargeLocation: Decodable {
    let id: Int64
    let name: String?
    let coordinates: GECoordinate
    let address: GEAddress
    let chargepoints: [GEChargepoint]
    let network: String?
    let url: String
    let faultReport: GEFaultReport?
    let verified: Bool
    let barrierFree: Bool?
    let `operator`: String?
    let generalInformation: String?
    let amenities: String?
    let locationDescription: String?
    let photos: [GEChargerPhoto]?
    let chargecards: [GEChargeCardId]?
    let openinghours: GEOpeningHours?
    let cost: GECost?

    enum CodingKeys: String, CodingKey {
        case id = "ge_id"
        case name, coordinates, address, chargepoints, network, url, verified, photos, chargecards
        case faultReport = "fault_report"
        case barrierFree = "barrierfree"
        case `operator`
        case generalInformation = "general_information"
        case amenities = "ladeweile"
        case locationDescription = "location_description"
        case openinghours, cost
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        name = c.stringOrFalse(.name)
        coordinates = try c.decode(GECoordinate.self, forKey: .coordinates)
        address = try c.decode(GEAddress.self, forKey: .address)
        chargepoints = try c.decode([GEChargepoint].self, forKey: .chargepoints)
        network = c.stringOrFalse(.network)
        url = try c.decode(String.self, forKey: .url)
        faultReport = GEFaultReport(from: c, key: .faultReport)
        verified = (try? c.decode(Bool.self, forKey: .verified)) ?? false
        barrierFree = try c.decodeIfPresent(Bool.self, forKey: .barrierFree)
        `operator` = c.stringOrFalse(.operator)
        generalInformation = c.stringOrFalse(.generalInformation)
        amenities = c.stringOrFalse(.amenities)
        locationDescription = c.stringOrFalse(.locationDescription)
        photos = c.listOrFalse([GEChargerPhoto].self, .photos)
        chargecards = c.listOrFalse([GEChargeCardId].self, .chargecards)
        openinghours = try c.decodeIfPresent(GEOpeningHours.self, forKey: .openinghours)
        cost = try c.decodeIfPresent(GECost.self, forKey: .cost)
    }

    func convert(apikey: String, isDetailed: Bool) -> ChargeLocation {
        ChargeLocation(
            id: id,
            dataSource: "goingelectric",
            name: name ?? "Ladestation",
            coordinates: coordinates.convert(),
            address: address.convert(),
            chargepoints: chargepoints.map { $0.convert() },
            network: network,
            dataSourceUrl: "https://www.goingelectric.de/",
            url: "https:\(url)",
            editUrl: "https:\(url)edit/",
            faultReport: faultReport?.convert(),
            verified: verified,
            barrierFree: barrierFree,
            operator: `operator`,
            generalInformation: generalInformation,
            amenities: amenities,
            locationDescription: locationDescription,
            photos: photos?.map { $0.convert(apikey: apikey) },
            chargecards: chargecards?.map { $0.convert() },
            accessibility: nil,
            openinghours: openinghours?.convert(),
            cost: cost?.convert(),
            license: nil,
            chargepriceData: ChargepriceData(
                country: address.country,
                network: network,
                plugTypes: chargepoints.map { $0.type }
            ),
            networkUrl: nil,
            chargerUrl: nil,
            timeRetrieved: Date(),
            isDetailed: isDetailed
        )
    }
}

// MARK: - Teil-Objekte

struct GECoordinate: Decodable {
    let lat: Double
    let lng: Double
    func convert() -> Coordinate { Coordinate(lat: lat, lng: lng) }
}

struct GEAddress: Decodable {
    let city: String?
    let country: String?
    let postcode: String?
    let street: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city = c.stringOrFalse(.city)
        country = c.stringOrFalse(.country)
        postcode = c.stringOrFalse(.postcode)
        street = c.stringOrFalse(.street)
    }

    enum CodingKeys: String, CodingKey { case city, country, postcode, street }
    func convert() -> Address { Address(city: city, country: country, postcode: postcode, street: street) }
}

struct GEChargepoint: Decodable {
    let type: String
    let power: Double
    let count: Int

    func convert() -> Chargepoint {
        Chargepoint(type: Self.convertTypeFromGE(type), power: power, count: count)
    }

    /// Intern → GE-Steckername (für API-Filterparameter).
    static func convertTypeToGE(_ type: String) -> String? {
        let C = Chargepoint.Connector.self
        switch type {
        case C.type1: return "Typ1"
        case C.type2Unknown: return "Typ2"
        case C.type3c: return "Typ3"
        case C.ccsUnknown: return "CCS"
        case C.ccsType2: return "Typ2"
        case C.schuko: return "Schuko"
        case C.chademo: return "CHAdeMO"
        case C.supercharger: return "Tesla Supercharger"
        case C.ceeBlau: return "CEE Blau"
        case C.ceeRot: return "CEE Rot"
        case C.teslaRoadsterHpc: return "Tesla HPC"
        default: return nil
        }
    }

    /// GE-Steckername → intern.
    static func convertTypeFromGE(_ type: String) -> String {
        let C = Chargepoint.Connector.self
        switch type {
        case "Typ1": return C.type1
        case "Typ2": return C.type2Unknown
        case "Typ3": return C.type3c
        case "Tesla Supercharger CCS": return C.ccsUnknown
        case "CCS": return C.ccsUnknown
        case "Schuko": return C.schuko
        case "CHAdeMO": return C.chademo
        case "Tesla Supercharger": return C.supercharger
        case "CEE Blau": return C.ceeBlau
        case "CEE Rot": return C.ceeRot
        case "Tesla HPC": return C.teslaRoadsterHpc
        default: return type
        }
    }
}

/// fault_report kann `false` (kein Bericht), `true` (leerer Bericht) oder ein Objekt sein.
struct GEFaultReport {
    let created: Date?
    let description: String?

    init(created: Date?, description: String?) {
        self.created = created
        self.description = description
    }

    /// Liest fault_report aus einem Container unter Berücksichtigung der false/true/Objekt-Varianten.
    init?<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) {
        if let bool = try? container.decode(Bool.self, forKey: key) {
            if bool { self.init(created: nil, description: "") } else { return nil }
            return
        }
        guard let obj = try? container.decode(Inner.self, forKey: key) else { return nil }
        self.init(created: obj.created.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                  description: obj.description)
    }

    private struct Inner: Decodable {
        let created: Int64?
        let description: String?
    }

    func convert() -> FaultReport { FaultReport(created: created, description: description) }
}

struct GEChargerPhoto: Decodable {
    /// GE liefert die Foto-ID als Ganzzahl.
    let id: Int
    func convert(apikey: String) -> ChargerPhoto {
        ChargerPhoto(
            id: String(id),
            source: .goingElectric(
                baseURL: "https://api.goingelectric.de/chargepoints/photo/?key=\(apikey)&id=\(id)"
            )
        )
    }
}

struct GEChargeCardId: Decodable {
    let id: Int64
    func convert() -> ChargeCardId { ChargeCardId(id: id) }
}

struct GECost: Decodable {
    let freecharging: Bool
    let freeparking: Bool
    let descriptionShort: String?
    let descriptionLong: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        freecharging = (try? c.decode(Bool.self, forKey: .freecharging)) ?? false
        freeparking = (try? c.decode(Bool.self, forKey: .freeparking)) ?? false
        descriptionShort = c.stringOrFalse(.descriptionShort)
        descriptionLong = c.stringOrFalse(.descriptionLong)
    }

    enum CodingKeys: String, CodingKey {
        case freecharging, freeparking
        case descriptionShort = "description_short"
        case descriptionLong = "description_long"
    }

    func convert() -> Cost {
        // GE: freecharging = false bedeutet „bezahlt ODER keine Info" – nur true ist aussagekräftig.
        Cost(
            freecharging: freecharging ? true : nil,
            freeparking: freeparking ? true : nil,
            descriptionShort: descriptionShort,
            descriptionLong: descriptionLong
        )
    }
}

struct GEOpeningHours: Decodable {
    let twentyfourSeven: Bool
    let description: String?
    let days: GEOpeningHoursDays?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        twentyfourSeven = (try? c.decode(Bool.self, forKey: .twentyfourSeven)) ?? false
        description = c.stringOrFalse(.description)
        days = try c.decodeIfPresent(GEOpeningHoursDays.self, forKey: .days)
    }

    enum CodingKeys: String, CodingKey {
        case twentyfourSeven = "24/7"
        case description, days
    }

    func convert() -> OpeningHours {
        OpeningHours(twentyfourSeven: twentyfourSeven, description: description, days: days?.convert())
    }
}

struct GEOpeningHoursDays: Decodable {
    let monday, tuesday, wednesday, thursday, friday, saturday, sunday, holiday: GEHours

    func convert() -> OpeningHoursDays {
        OpeningHoursDays(
            monday: monday.convert(), tuesday: tuesday.convert(), wednesday: wednesday.convert(),
            thursday: thursday.convert(), friday: friday.convert(), saturday: saturday.convert(),
            sunday: sunday.convert(), holiday: holiday.convert()
        )
    }
}

/// GE liefert Öffnungszeiten als String, z.B. "from 08:00 till 20:00", "closed", "around the clock".
struct GEHours: Decodable {
    let startMinutes: Int?
    let endMinutes: Int?

    init(from decoder: Decoder) throws {
        let str = try decoder.singleValueContainer().decode(String.self)
        (startMinutes, endMinutes) = Self.parse(str)
    }

    private static let dayEnd = 23 * 60 + 59 // LocalTime.MAX-Äquivalent

    private static func parse(_ str: String) -> (Int?, Int?) {
        if str == "closed" { return (nil, nil) }
        if str == "around the clock" { return (0, dayEnd) }
        // "from HH:mm till HH:mm"
        guard let fromRange = str.range(of: "from "),
              let tillRange = str.range(of: " till ") else {
            return (0, 0) // seltener Sonderfall im Original ebenfalls auf MIN gesetzt
        }
        let startStr = String(str[fromRange.upperBound..<tillRange.lowerBound])
        let endStr = String(str[tillRange.upperBound...])
        let start = minutes(from: startStr) ?? 0
        let end = endStr == "24:00" ? dayEnd : (minutes(from: endStr) ?? 0)
        return (start, end)
    }

    private static func minutes(from time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    func convert() -> Hours? {
        guard let startMinutes, let endMinutes else { return nil }
        return Hours(startMinutes: startMinutes, endMinutes: endMinutes)
    }
}

// MARK: - Referenzdaten

struct GEChargeCard: Decodable, Sendable, Hashable {
    let id: Int64
    let name: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "card_id"
        case name, url
    }
}

struct GEReferenceData: ReferenceData, Sendable {
    let plugs: [String]
    let networks: [String]
    let chargecards: [GEChargeCard]
}
