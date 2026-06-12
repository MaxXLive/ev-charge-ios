//
//  NobilModels.swift
//  evmap
//
//  Nobil-JSON-Modelle (Skandinavien) + Mapping. Portiert aus EVMap (Android, MIT) –
//  api/nobil/NobilModel.kt. Nobil liefert in der Rectangle-Suche bereits Volldaten,
//  daher kein separater Detail-Abruf nötig (isDetailed = true).
//

import Foundation

// MARK: - Requests

struct NobilRectangleSearchRequest: Encodable {
    let apikey: String
    let northeast: String
    let southwest: String
    let limit: Int
    let action = "search"
    let type = "rectangle"
    let format = "json"
    let apiversion = "3"
}

struct NobilRadiusSearchRequest: Encodable {
    let apikey: String
    let lat: Double
    let long: Double
    let distance: Double // Meter
    let limit: Int
    let action = "search"
    let type = "near"
    let format = "json"
    let apiversion = "3"
}

// MARK: - Reference Data (trivial)

struct NobilReferenceData: ReferenceData, Sendable {}

// MARK: - Response

struct NobilResponseData: Decodable {
    let error: String?
    let rights: String?
    let chargerStations: [NobilChargerStation]?

    enum CodingKeys: String, CodingKey {
        case error
        case rights = "Rights"
        case chargerStations = "chargerstations"
    }
}

struct NobilChargerStation: Decodable {
    let data: NobilStationData
    let attributes: NobilAttributes

    enum CodingKeys: String, CodingKey {
        case data = "csmd"
        case attributes = "attr"
    }
}

/// Generisches Nobil-Attribut. `attrval` kann String oder Zahl sein.
struct NobilAttr: Decodable {
    let attrValId: String
    let attrTrans: String
    let attrVal: String?

    enum CodingKeys: String, CodingKey {
        case attrValId = "attrvalid"
        case attrTrans = "trans"
        case attrVal = "attrval"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attrValId = (try? c.decode(String.self, forKey: .attrValId)) ?? ""
        attrTrans = (try? c.decode(String.self, forKey: .attrTrans)) ?? ""
        if let s = try? c.decode(String.self, forKey: .attrVal) {
            attrVal = s
        } else if let i = try? c.decode(Int.self, forKey: .attrVal) {
            attrVal = String(i)
        } else if let d = try? c.decode(Double.self, forKey: .attrVal) {
            attrVal = String(d)
        } else {
            attrVal = nil
        }
    }
}

struct NobilAttributes: Decodable {
    let st: [String: NobilAttr]
    let conn: [String: [String: NobilAttr]]
}

struct NobilStationData: Decodable {
    let id: Int64
    let name: String
    let ocpiId: String?
    let street: String?
    let houseNumber: String?
    let zipCode: String?
    let city: String?
    let ownedBy: String?
    let `operator`: String?
    let position: Coordinate
    let image: String
    let userComment: String?
    let description: String?
    let landCode: String
    let internationalId: String
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case ocpiId = "ocpidb_mapping_stasjon_id"
        case street = "Street"
        case houseNumber = "House_number"
        case zipCode = "Zipcode"
        case city = "City"
        case ownedBy = "Owned_by"
        case `operator` = "Operator"
        case position = "Position"
        case image = "Image"
        case userComment = "User_comment"
        case description = "Description_of_location"
        case landCode = "Land_code"
        case internationalId = "International_id"
        case updated = "Updated"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        ocpiId = try? c.decodeIfPresent(String.self, forKey: .ocpiId)
        street = try? c.decodeIfPresent(String.self, forKey: .street)
        houseNumber = try? c.decodeIfPresent(String.self, forKey: .houseNumber)
        zipCode = try? c.decodeIfPresent(String.self, forKey: .zipCode)
        city = try? c.decodeIfPresent(String.self, forKey: .city)
        ownedBy = try? c.decodeIfPresent(String.self, forKey: .ownedBy)
        `operator` = try? c.decodeIfPresent(String.self, forKey: .operator)
        image = (try? c.decode(String.self, forKey: .image)) ?? ""
        userComment = try? c.decodeIfPresent(String.self, forKey: .userComment)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        landCode = (try? c.decode(String.self, forKey: .landCode)) ?? ""
        internationalId = (try? c.decode(String.self, forKey: .internationalId)) ?? ""

        let posStr = (try? c.decode(String.self, forKey: .position)) ?? ""
        position = Self.parsePosition(posStr)
        updated = Self.parseDate(try? c.decodeIfPresent(String.self, forKey: .updated))
    }

    private static func parsePosition(_ s: String) -> Coordinate {
        // Format "(lat, lng)"
        let cleaned = s.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else {
            return Coordinate(lat: 0, lng: 0)
        }
        return Coordinate(lat: lat, lng: lng)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        return f
    }()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return dateFormatter.date(from: s)
    }
}

// MARK: - Mapping

extension NobilChargerStation {
    func convert(license: String, filters: FilterValues?) -> ChargeLocation? {
        let chargepoints = attributes.conn.values.compactMap { Self.makeChargepoint(from: $0) }
        guard !chargepoints.isEmpty else { return nil }

        // Lokale Filter (Nobil filtert serverseitig nicht).
        let minPower = filters?.sliderValue("min_power") ?? 0
        let connectors = filters?.multipleChoiceValue("connectors")
        let minConnectors = filters?.sliderValue("min_connectors") ?? 0
        let matching = chargepoints
            .filter { ($0.power ?? 0) >= Double(minPower) }
            .filter { cp in
                if let cv = connectors, !cv.all { return cv.values.contains(cp.type) }
                return true
            }
        if matching.count < minConnectors { return nil }

        let st = attributes.st
        let twentyfourSeven = st["24"]?.attrTrans == "Yes"
        let accessibility = st["2"]?.attrTrans
        let freeparking: Bool? = {
            switch st["7"]?.attrTrans {
            case "Yes": return false // Parkgebühr ja -> nicht kostenlos
            case "No": return true
            default: return nil
            }
        }()

        let country: String = {
            switch data.landCode {
            case "NOR": return "Norway"
            case "SWE": return "Sweden"
            default: return ""
            }
        }()
        let editUrl: String = data.landCode == "SWE"
            ? "https://www.energimyndigheten.se/klimat/transporter/laddinfrastruktur/"
            : "mailto:post@nobil.no?subject=Charging%20station%20\(data.internationalId)"

        let verified = data.ocpiId != nil
            || (data.updated.map { $0 > Calendar.current.date(byAdding: .month, value: -6, to: .now)! } ?? false)

        let location = ChargeLocation(
            id: data.id,
            dataSource: "nobil",
            name: stripHTML(data.name),
            coordinates: data.position,
            address: Address(
                city: data.city,
                country: country,
                postcode: data.zipCode,
                street: [data.street, data.houseNumber].compactMap { $0 }.joined(separator: " ")
            ),
            chargepoints: chargepoints,
            network: data.operator.map(stripHTML),
            dataSourceUrl: "https://nobil.no/",
            url: nil,
            editUrl: editUrl,
            faultReport: nil,
            verified: verified,
            barrierFree: nil,
            operator: data.ownedBy.map(stripHTML),
            generalInformation: data.userComment.map(stripHTML),
            amenities: nil,
            locationDescription: data.description.map(stripHTML),
            photos: photo(),
            chargecards: nil,
            accessibility: accessibility,
            openinghours: twentyfourSeven ? OpeningHours(twentyfourSeven: true, description: nil, days: nil) : nil,
            cost: Cost(freeparking: freeparking, descriptionLong: paymentMethods()),
            license: license,
            chargepriceData: nil,
            networkUrl: nil,
            chargerUrl: nil,
            timeRetrieved: Date(),
            isDetailed: true
        )

        // Filter, die sich auf das Gesamtobjekt beziehen.
        if let acc = filters?.multipleChoiceValue("accessibilities"), !acc.all {
            if !acc.values.contains(location.accessibility ?? "") { return nil }
        }
        if filters?.booleanValue("freeparking") == true, location.cost?.freeparking != true { return nil }
        if filters?.booleanValue("open_247") == true, location.openinghours?.twentyfourSeven != true { return nil }

        return location
    }

    private func photo() -> [ChargerPhoto]? {
        guard data.image.range(of: #"^\d+\.\w+$"#, options: .regularExpression) != nil else { return nil }
        let base = "https://www.nobil.no/img/ladestasjonbilder/"
        return [ChargerPhoto(
            id: data.image,
            source: .simple(small: base + "tn_" + data.image, large: base + data.image)
        )]
    }

    private func paymentMethods() -> String? {
        var methods = Set<String>()
        for conn in attributes.conn.values {
            switch conn["19"]?.attrValId {
            case "1": methods.insert("Handy")
            case "2": methods.insert("Bankkarte")
            case "10": methods.insert("Sonstige")
            case "20": methods.formUnion(["Handy", "Ladekarte"])
            case "21": methods.formUnion(["Bankkarte", "Ladekarte"])
            case "25": methods.formUnion(["Bankkarte", "Ladekarte", "Handy"])
            default: break
            }
        }
        guard !methods.isEmpty else { return nil }
        return "Akzeptierte Zahlungsmethoden: " + methods.sorted().joined(separator: ", ")
    }

    private func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&aelig;", with: "æ")
            .replacingOccurrences(of: "&oslash;", with: "ø")
            .replacingOccurrences(of: "&aring;", with: "å")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Erzeugt einen Ladepunkt aus den Connector-Attributen (oder nil, wenn nicht ladend, z.B. Wasserstoff).
    static func makeChargepoint(from attribs: [String: NobilAttr]) -> Chargepoint? {
        let isFixedCable = attribs["25"]?.attrTrans == "Yes"
        let C = Chargepoint.Connector.self
        let type: String
        switch attribs["4"]?.attrValId {
        case "30": type = C.chademo
        case "31": type = C.type1
        case "32": type = isFixedCable ? C.type2Plug : C.type2Socket
        case "39": type = C.ccsUnknown
        case "40": type = C.supercharger
        case "70", "82": return nil // Wasserstoff / Biogas
        default: type = ""
        }

        let power = powerMap[attribs["5"]?.attrValId ?? ""] ?? nil
        let voltage = attribs["12"]?.attrVal.flatMap(Double.init)
        let current = attribs["31"]?.attrVal.flatMap(Double.init)
        let evseUid = attribs["27"]?.attrVal
        let evseId = attribs["28"]?.attrVal

        return Chargepoint(
            type: type,
            power: power,
            count: 1,
            current: current,
            voltage: voltage,
            evseIds: evseId.map { [$0] },
            evseUIds: evseUid.map { [$0] }
        )
    }

    /// Nobil-Leistungs-Attribut-ID → kW (https://nobil.no/admin/attributes.php).
    private static let powerMap: [String: Double?] = [
        "7": 3.6, "8": 7.4, "10": 11, "11": 22, "12": 43, "13": 50,
        "16": 11, "17": 22, "18": 43, "19": 20, "22": 135, "23": 100,
        "24": 150, "25": 350, "29": 75, "30": 225, "31": 250, "32": 200,
        "33": 300, "36": 400, "37": 30, "38": 62.5, "39": 500, "41": 175,
        "42": 180, "43": 600, "44": 700, "45": 800, "46": 320, "47": 900,
        "48": 1000, "49": 1100, "50": 1200, "51": 1300, "52": 1400, "53": 1500,
    ]
}
