//
//  OCMModels.swift
//  evcharge
//
//  Open-Charge-Map-JSON-Modelle + Mapping auf das Domain-Modell.
//  Portiert aus EVMap (Android, MIT) – api/openchargemap/OpenChargeMapModel.kt
//

import Foundation

// Status-IDs (OCM)
private let faultStatuses: Set<Int64> = [30, 75, 100, 150]
private let removedStatuses: Set<Int64> = [200, 210]
private let faultReportCommentType: Int64 = 1000

/// Lenient ISO-8601-Parser (OCM liefert teils mit/ohne Sekundenbruchteile).
enum OCMDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        return withFraction.date(from: s) ?? plain.date(from: s)
    }
}

// MARK: - Referenzdaten

struct OCMReferenceData: ReferenceData, Sendable, Decodable {
    let connectionTypes: [OCMConnectionType]
    let countries: [OCMCountry]
    let operators: [OCMOperator]

    enum CodingKeys: String, CodingKey {
        case connectionTypes = "ConnectionTypes"
        case countries = "Countries"
        case operators = "Operators"
    }

    func operatorTitle(_ id: Int64?) -> String? {
        guard let id else { return nil }
        return operators.first { $0.id == id }?.title
    }
    func country(_ id: Int64) -> OCMCountry? { countries.first { $0.id == id } }
}

struct OCMConnectionType: Decodable, Sendable {
    let id: Int64
    let title: String
    enum CodingKeys: String, CodingKey { case id = "ID", title = "Title" }
}

struct OCMCountry: Decodable, Sendable {
    let id: Int64
    let isoCode: String
    let title: String
    enum CodingKeys: String, CodingKey { case id = "ID", isoCode = "ISOCode", title = "Title" }
}

struct OCMOperator: Decodable, Sendable {
    let id: Int64
    let title: String
    let websiteUrl: String?
    enum CodingKeys: String, CodingKey { case id = "ID", title = "Title", websiteUrl = "WebsiteURL" }
}

// MARK: - POI

struct OCMChargepoint: Decodable {
    let id: Int64
    let recentlyVerified: Bool
    let cost: String?
    let addressInfo: OCMAddressInfo
    let connections: [OCMConnection]
    let generalComments: String?
    let operatorInfo: OCMOperatorInfo?
    let operatorId: Int64?
    let dataProvider: OCMDataProvider?
    let mediaItems: [OCMMediaItem]?
    let statusTypeId: Int64?
    let statusType: OCMStatusType?
    let userComments: [OCMUserComment]?
    let lastStatusUpdate: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case recentlyVerified = "IsRecentlyVerified"
        case cost = "UsageCost"
        case addressInfo = "AddressInfo"
        case connections = "Connections"
        case generalComments = "GeneralComments"
        case operatorInfo = "OperatorInfo"
        case operatorId = "OperatorID"
        case dataProvider = "DataProvider"
        case mediaItems = "MediaItems"
        case statusTypeId = "StatusTypeID"
        case statusType = "StatusType"
        case userComments = "UserComments"
        case lastStatusUpdate = "DateLastStatusUpdate"
    }

    /// Ob dieser POI entfernt/stillgelegt ist (nicht anzeigen).
    var isRemoved: Bool {
        if let s = statusTypeId, removedStatuses.contains(s) { return true }
        return false
    }

    var hasFault: Bool {
        if let s = statusTypeId, faultStatuses.contains(s) { return true }
        return connections.contains { $0.statusTypeId.map { faultStatuses.contains($0) } ?? false }
    }

    func convert(refData: OCMReferenceData, isDetailed: Bool) -> ChargeLocation {
        let network = operatorInfo?.title ?? refData.operatorTitle(operatorId)
        let licenseText: String? = dataProvider.map {
            "© \($0.title)" + ($0.license.map { ". \($0)" } ?? "")
        }
        return ChargeLocation(
            id: id,
            dataSource: "openchargemap",
            name: addressInfo.title,
            coordinates: Coordinate(lat: addressInfo.latitude, lng: addressInfo.longitude),
            address: addressInfo.toAddress(refData),
            chargepoints: connections.map { $0.convert(refData) },
            network: network,
            dataSourceUrl: "https://openchargemap.org/",
            url: "https://map.openchargemap.io/?id=\(id)",
            editUrl: "https://map.openchargemap.io/?id=\(id)",
            faultReport: faultReport(),
            verified: recentlyVerified,
            barrierFree: nil,
            operator: nil,
            generalInformation: generalComments,
            amenities: nil,
            locationDescription: nil,
            photos: mediaItems?.compactMap { $0.convert() },
            chargecards: nil,
            accessibility: addressInfo.accessComments,
            openinghours: nil,
            cost: cost.flatMap { $0.isBlank ? nil : Cost(descriptionShort: $0) },
            license: licenseText,
            chargepriceData: ChargepriceData(
                country: addressInfo.countryISO(refData),
                network: operatorId.map(String.init),
                plugTypes: connections.map { "\($0.connectionTypeId),\($0.currentTypeId ?? 0)" }
            ),
            networkUrl: operatorInfo?.websiteUrl,
            chargerUrl: addressInfo.relatedUrl,
            timeRetrieved: Date(),
            isDetailed: isDetailed
        )
    }

    private func faultReport() -> FaultReport? {
        guard hasFault else { return nil }
        if let comments = userComments {
            let faultComment = comments
                .filter { $0.commentTypeId == faultReportCommentType }
                .max { ($0.dateCreated ?? "") < ($1.dateCreated ?? "") }
            if let fc = faultComment {
                return FaultReport(created: OCMDate.parse(fc.dateCreated), description: fc.comment ?? "")
            }
        }
        if let st = statusType, let id = statusTypeId, faultStatuses.contains(id) {
            return FaultReport(created: OCMDate.parse(lastStatusUpdate), description: st.title)
        }
        return FaultReport(created: nil, description: "")
    }
}

struct OCMAddressInfo: Decodable {
    let title: String
    let addressLine1: String?
    let addressLine2: String?
    let town: String?
    let postcode: String?
    let countryId: Int64
    let latitude: Double
    let longitude: Double
    let accessComments: String?
    let relatedUrl: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case addressLine1 = "AddressLine1"
        case addressLine2 = "AddressLine2"
        case town = "Town"
        case postcode = "Postcode"
        case countryId = "CountryID"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case accessComments = "AccessComments"
        case relatedUrl = "RelatedURL"
    }

    func toAddress(_ refData: OCMReferenceData) -> Address {
        Address(
            city: town,
            country: refData.country(countryId)?.title,
            postcode: postcode,
            street: [addressLine1, addressLine2].compactMap { $0 }.joined(separator: ", ")
        )
    }

    func countryISO(_ refData: OCMReferenceData) -> String? {
        refData.country(countryId)?.isoCode
    }
}

struct OCMConnection: Decodable {
    let connectionTypeId: Int64
    let currentTypeId: Int64?
    let amps: Int?
    let voltage: Int?
    let power: Double?
    let quantity: Int?
    let statusTypeId: Int64?

    enum CodingKeys: String, CodingKey {
        case connectionTypeId = "ConnectionTypeID"
        case currentTypeId = "CurrentTypeID"
        case amps = "Amps"
        case voltage = "Voltage"
        case power = "PowerKW"
        case quantity = "Quantity"
        case statusTypeId = "StatusTypeID"
    }

    func convert(_ refData: OCMReferenceData) -> Chargepoint {
        Chargepoint(
            type: Self.connectorType(connectionTypeId, refData),
            power: power,
            count: quantity ?? 1,
            current: amps.map(Double.init),
            voltage: voltage.map(Double.init)
        )
    }

    static func connectorType(_ id: Int64, _ refData: OCMReferenceData) -> String {
        let C = Chargepoint.Connector.self
        switch id {
        case 32: return C.ccsType1
        case 33: return C.ccsType2
        case 2: return C.chademo
        case 16: return C.ceeBlau
        case 17: return C.ceeRot
        case 28: return C.schuko
        case 8: return C.teslaRoadsterHpc
        case 27, 30: return C.supercharger
        case 25: return C.type2Socket
        case 1036: return C.type2Plug
        case 1: return C.type1
        case 36: return C.type3a
        case 26: return C.type3c
        default: return refData.connectionTypes.first { $0.id == id }?.title ?? ""
        }
    }
}

struct OCMOperatorInfo: Decodable {
    let title: String?
    let websiteUrl: String?
    enum CodingKeys: String, CodingKey { case title = "Title", websiteUrl = "WebsiteURL" }
}

struct OCMDataProvider: Decodable {
    let title: String
    let license: String?
    enum CodingKeys: String, CodingKey { case title = "Title", license = "License" }
}

struct OCMStatusType: Decodable {
    let id: Int64
    let title: String
    enum CodingKeys: String, CodingKey { case id = "ID", title = "Title" }
}

struct OCMUserComment: Decodable {
    let commentTypeId: Int64
    let comment: String?
    let dateCreated: String?
    enum CodingKeys: String, CodingKey {
        case commentTypeId = "CommentTypeID"
        case comment = "Comment"
        case dateCreated = "DateCreated"
    }
}

struct OCMMediaItem: Decodable {
    let id: Int64
    let url: String
    let thumbUrl: String
    let isVideo: Bool
    let isExternalResource: Bool

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case url = "ItemURL"
        case thumbUrl = "ItemThumbnailURL"
        case isVideo = "IsVideo"
        case isExternalResource = "IsExternalResource"
    }

    func convert() -> ChargerPhoto? {
        guard !isVideo, !isExternalResource else { return nil }
        return ChargerPhoto(id: String(id), source: .openChargeMap(thumb: thumbUrl, large: url))
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
