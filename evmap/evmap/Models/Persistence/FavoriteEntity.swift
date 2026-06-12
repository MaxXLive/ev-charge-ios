//
//  FavoriteEntity.swift
//  evmap
//
//  SwiftData-Modell für Favoriten (Android-Pendant: Room `Favorite`).
//  Speichert genug, um den Favoriten in der Liste zu zeigen und die Karte zu zentrieren,
//  ohne neu laden zu müssen.
//

import Foundation
import SwiftData

@Model
final class FavoriteEntity {
    /// Charger-ID innerhalb der Datenquelle.
    var chargerId: Int64
    /// Datenquelle, z.B. "goingelectric".
    var dataSource: String
    var name: String
    var latitude: Double
    var longitude: Double
    var network: String?
    var maxPower: Double?
    var dateAdded: Date

    init(
        chargerId: Int64,
        dataSource: String,
        name: String,
        latitude: Double,
        longitude: Double,
        network: String?,
        maxPower: Double?,
        dateAdded: Date = .now
    ) {
        self.chargerId = chargerId
        self.dataSource = dataSource
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.network = network
        self.maxPower = maxPower
        self.dateAdded = dateAdded
    }

    convenience init(from location: ChargeLocation) {
        self.init(
            chargerId: location.id,
            dataSource: location.dataSource,
            name: location.name,
            latitude: location.coordinates.lat,
            longitude: location.coordinates.lng,
            network: location.network,
            maxPower: location.maxPower
        )
    }
}
