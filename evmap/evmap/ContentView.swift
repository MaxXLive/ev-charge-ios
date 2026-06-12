//
//  ContentView.swift
//  evmap
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            MapView()
                .tabItem { Label("Karte", systemImage: "map") }
                .tag(AppTab.map)

            FavoritesView()
                .tabItem { Label("Favoriten", systemImage: "star") }
                .tag(AppTab.favorites)

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(appState)
        .environment(locationManager)
        .preferredColorScheme(appearance.colorScheme)
        .fullScreenCover(isPresented: .constant(!onboardingDone)) {
            OnboardingView { onboardingDone = true }
        }
        .task {
            // Standort erst anfragen, wenn das Onboarding abgeschlossen ist.
            if onboardingDone { locationManager.request() }
        }
        .onChange(of: onboardingDone) {
            if onboardingDone { locationManager.request() }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FavoriteEntity.self, inMemory: true)
}
