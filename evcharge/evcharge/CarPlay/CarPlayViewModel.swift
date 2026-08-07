//
//  CarPlayViewModel.swift
//  evcharge
//
//  Lädt Ladestationen und Favoriten für CarPlay. Radius-basiert statt Kamera-basiert.
//

import CoreData
import CoreLocation
import Foundation
import SwiftData

@MainActor
final class CarPlayViewModel {
    private var apis: [any ChargepointAPI]
    private(set) var referenceDataMap: [String: ReferenceData] = [:]
    private let availabilityService = AvailabilityService()

    private(set) var nearbyChargers: [ChargeLocation] = []
    private(set) var favorites: [FavoriteEntity] = []
    private(set) var activeFilterProfile: FilterProfileEntity?

    private var loadTask: Task<Void, Never>?
    private(set) var searchCenter: CLLocationCoordinate2D?
    private var lastLoadedCenter: CLLocationCoordinate2D?
    private var favoritesObserver: NSObjectProtocol?

    var onNearbyUpdated: (() -> Void)?
    var onFavoritesUpdated: (() -> Void)?

    init() {
        let sources = DataSourceID.selectedSet
        let result = sources.compactMap { $0.makeAPI() }
        self.apis = result.isEmpty ? [GoingElectricAPI(apikey: Secrets.goingElectricKey)] : result
    }

    func start() async {
        await loadReferenceData()
        loadFavorites()
        startFavoritesObserver()
        await loadNearbyChargers()
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        if let obs = favoritesObserver {
            NotificationCenter.default.removeObserver(obs)
            favoritesObserver = nil
        }
    }

    func setSearchCenter(_ coordinate: CLLocationCoordinate2D?) {
        searchCenter = coordinate
        // Only reload if center moved >2 km from last loaded position
        if let new = coordinate, let last = lastLoadedCenter {
            let dist = CLLocation(latitude: new.latitude, longitude: new.longitude)
                .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            guard dist > 2000 else { return }
        }
        reloadNearby()
    }

    func setFilterProfile(_ profile: FilterProfileEntity?) {
        activeFilterProfile = profile
        reloadNearby()
    }

    func reloadNearby() {
        loadTask?.cancel()
        loadTask = Task { await self.loadNearbyChargers() }
    }

    func isFavorite(id: Int64, dataSource: String) -> Bool {
        favorites.contains { $0.chargerId == id && $0.dataSource == dataSource }
    }

    func toggleFavorite(location: ChargeLocation) {
        let context = ModelContext(SharedContainer.modelContainer)
        if favorites.first(where: { $0.chargerId == location.id && $0.dataSource == location.dataSource }) != nil {
            let id = location.id
            let ds = location.dataSource
            let descriptor = FetchDescriptor<FavoriteEntity>(
                predicate: #Predicate { $0.chargerId == id && $0.dataSource == ds }
            )
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
            }
        } else {
            context.insert(FavoriteEntity(from: location))
        }
        try? context.save()
        loadFavorites()
        onFavoritesUpdated?()
    }

    func loadFavorites() {
        let context = ModelContext(SharedContainer.modelContainer)
        let descriptor = FetchDescriptor<FavoriteEntity>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        favorites = (try? context.fetch(descriptor)) ?? []
    }

    func loadFilterProfiles() -> [FilterProfileEntity] {
        let context = ModelContext(SharedContainer.modelContainer)
        let descriptor = FetchDescriptor<FilterProfileEntity>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func loadDetail(for location: ChargeLocation) async -> ChargeLocation? {
        guard let api = apis.first(where: { $0.id == location.dataSource }),
              let rd = referenceDataMap[api.id] else { return nil }
        let result = await api.getChargepointDetail(referenceData: rd, id: location.id)
        if case let .success(detail) = result { return detail }
        return nil
    }

    // MARK: - Private

    private func startFavoritesObserver() {
        favoritesObserver = NotificationCenter.default.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadFavorites()
            self?.onFavoritesUpdated?()
        }
    }

    private var availableFilters: [Filter] {
        var seen = Set<String>()
        var result: [Filter] = []
        for api in apis {
            guard let rd = referenceDataMap[api.id] else { continue }
            for filter in api.getFilters(referenceData: rd) {
                if seen.insert(filter.key).inserted { result.append(filter) }
            }
        }
        return result
    }

    private func buildFilterValues(from profile: FilterProfileEntity) -> FilterValues {
        let profileValues = profile.filterValues
        return availableFilters.map { f in
            let value = profileValues.first { $0.key == f.key } ?? f.defaultValue
            return FilterWithValue(filter: f, value: value)
        }
    }

    private func loadReferenceData() async {
        await withTaskGroup(of: (String, ReferenceData)?.self) { group in
            for api in apis {
                group.addTask {
                    if case let .success(rd) = await api.getReferenceData() {
                        return (api.id, rd)
                    }
                    return nil
                }
            }
            for await pair in group {
                if let (id, rd) = pair {
                    referenceDataMap[id] = rd
                }
            }
        }
    }

    private func loadNearbyChargers() async {
        let center = searchCenter ?? LocationManager.shared.currentLocation
        guard let center else { return }

        let coordinate = Coordinate(lat: center.latitude, lng: center.longitude)
        let filterValues: FilterValues? = activeFilterProfile.map { buildFilterValues(from: $0) }

        var collected: [ChargeLocation] = []
        await withTaskGroup(of: [ChargeLocation].self) { group in
            for api in apis {
                guard let rd = referenceDataMap[api.id] else { continue }
                group.addTask {
                    let result = await api.getChargepointsRadius(
                        referenceData: rd,
                        location: coordinate,
                        radius: 10,
                        zoom: 14,
                        useClustering: false,
                        filters: filterValues
                    )
                    guard case let .success(list) = result else { return [] }
                    return list.items.compactMap {
                        if case let .location(loc) = $0 { return loc }
                        return nil
                    }
                }
            }
            for await chunk in group { collected.append(contentsOf: chunk) }
        }

        lastLoadedCenter = center
        let clCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)
        // Deduplicate by rounding coords to ~10m grid (avoids same station from multiple sources)
        var seen = Set<String>()
        let deduped = collected.filter { loc in
            let key = String(format: "%.4f,%.4f", loc.coordinates.lat, loc.coordinates.lng)
            return seen.insert(key).inserted
        }
        nearbyChargers = Array(
            deduped
                .sorted {
                    let a = CLLocation(latitude: $0.coordinates.lat, longitude: $0.coordinates.lng)
                    let b = CLLocation(latitude: $1.coordinates.lat, longitude: $1.coordinates.lng)
                    return a.distance(from: clCenter) < b.distance(from: clCenter)
                }
                .prefix(12)
        )
        onNearbyUpdated?()
    }
}
