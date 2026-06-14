//
//  SharedContainer.swift
//  evmap
//
//  Gemeinsamer SwiftData ModelContainer für App-Scene und CarPlay-Scene.
//

import SwiftData

enum SharedContainer {
    static let modelContainer: ModelContainer = {
        try! ModelContainer(for: FavoriteEntity.self, FilterProfileEntity.self)
    }()
}
