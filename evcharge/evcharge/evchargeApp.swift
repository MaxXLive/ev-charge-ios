//
//  evchargeApp.swift
//  evcharge
//

import SwiftData
import SwiftUI

@main
struct evchargeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedContainer.modelContainer)
    }
}
