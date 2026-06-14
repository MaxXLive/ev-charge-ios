//
//  evmapApp.swift
//  evmap
//

import SwiftData
import SwiftUI

@main
struct evmapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedContainer.modelContainer)
    }
}
