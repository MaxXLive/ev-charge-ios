//
//  FavoritesView.swift
//  evcharge
//
//  Liste der favorisierten Ladestationen (Android-Pendant: FavoritesFragment).
//

import CoreLocation
import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("units") private var units: DistanceUnit = .kilometers
    @Query(sort: \FavoriteEntity.dateAdded, order: .reverse) private var favorites: [FavoriteEntity]

    private var sortedFavorites: [FavoriteEntity] {
        guard let user = locationManager.currentLocation else { return favorites }
        let from = CLLocation(latitude: user.latitude, longitude: user.longitude)
        return favorites.sorted {
            from.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < from.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "Keine Favoriten",
                        systemImage: "star",
                        description: Text("Tippe auf der Karte bei einer Station auf den Stern.")
                    )
                } else {
                    List {
                        ForEach(sortedFavorites) { fav in
                            Button {
                                openOnMap(fav)
                            } label: {
                                row(fav)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Favoriten")
        }
    }

    private func row(_ fav: FavoriteEntity) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ChargerStyle.color(forPower: fav.maxPower))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name).font(.body)
                if let network = fav.network {
                    Text(network).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let power = fav.maxPower, power > 0 {
                    Text("\(Int(power)) kW").font(.caption).foregroundStyle(.secondary)
                }
                if let dist = distanceText(fav) {
                    Text(dist).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func distanceText(_ fav: FavoriteEntity) -> String? {
        guard let user = locationManager.currentLocation else { return nil }
        let meters = CLLocation(latitude: user.latitude, longitude: user.longitude)
            .distance(from: CLLocation(latitude: fav.latitude, longitude: fav.longitude))
        switch units {
        case .kilometers:
            if meters < 1000 { return "\(Int(meters)) m" }
            return String(format: "%.1f km", meters / 1000)
        case .miles:
            let miles = meters / 1609.344
            if miles < 0.1 { return "\(Int(meters * 3.28084)) ft" }
            return String(format: "%.1f mi", miles)
        }
    }

    private func openOnMap(_ fav: FavoriteEntity) {
        appState.mapTarget = Coordinate(lat: fav.latitude, lng: fav.longitude)
        appState.selectedTab = .map
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedFavorites[index])
        }
    }
}
