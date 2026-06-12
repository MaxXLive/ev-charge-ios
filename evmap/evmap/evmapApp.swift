//
//  evmapApp.swift
//  evmap
//
//  Created by Ermackov, Max (415) on 12.06.26.
//

import SwiftData
import SwiftUI

@main
struct evmapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FavoriteEntity.self, FilterProfileEntity.self])
    }
}
