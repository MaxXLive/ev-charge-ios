//
//  AppState.swift
//  evmap
//
//  Tab-übergreifender, beobachtbarer App-Zustand (z.B. „Favorit auf Karte zeigen").
//

import Observation

enum AppTab: Hashable {
    case map, favorites, settings
}

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .map
    /// Wenn gesetzt, zentriert die Karte auf diese Koordinate (z.B. aus Favoriten).
    var mapTarget: Coordinate?
}
