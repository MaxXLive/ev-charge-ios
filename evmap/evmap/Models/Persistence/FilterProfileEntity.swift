//
//  FilterProfileEntity.swift
//  evmap
//
//  SwiftData-Modell für gespeicherte Filter-Profile (Android-Pendant: Room `FilterProfile`).
//

import Foundation
import SwiftData

@Model
final class FilterProfileEntity {
    var name: String
    var dataSource: String
    /// JSON-kodierte Filterwerte (siehe FilterSnapshot).
    var data: Data
    var dateCreated: Date

    init(name: String, dataSource: String, data: Data, dateCreated: Date = .now) {
        self.name = name
        self.dataSource = dataSource
        self.data = data
        self.dateCreated = dateCreated
    }

    var filterValues: [FilterValue] { FilterSnapshot.decode(data) }
}
