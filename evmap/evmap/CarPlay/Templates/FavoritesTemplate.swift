//
//  FavoritesTemplate.swift
//  evmap
//
//  CPListTemplate: Liste gespeicherter Favoriten.
//

import CarPlay
import MapKit

@MainActor
final class FavoritesTemplate {
    let template: CPListTemplate
    private let viewModel: CarPlayViewModel
    private weak var interfaceController: CPInterfaceController?

    init(viewModel: CarPlayViewModel, interfaceController: CPInterfaceController) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController

        self.template = CPListTemplate(title: String(localized: "Favoriten"), sections: [])
        self.template.tabImage = UIImage(systemName: "star")

        viewModel.onFavoritesUpdated = { [weak self] in
            Task { @MainActor in self?.updateList() }
        }
        updateList()
    }

    private func updateList() {
        let favorites = viewModel.favorites
        if favorites.isEmpty {
            let empty = CPListSection(
                items: [],
                header: String(localized: "Keine Favoriten gespeichert"),
                sectionIndexTitle: nil
            )
            template.updateSections([empty])
            return
        }
        let items = favorites.map { fav -> CPListItem in
            var detail = fav.network ?? ""
            if let power = fav.maxPower {
                let powerStr = formatPower(power)
                detail = detail.isEmpty ? powerStr : "\(detail) · \(powerStr)"
            }
            let item = CPListItem(text: fav.name, detailText: detail.isEmpty ? nil : detail)
            item.handler = { [weak self] _, completion in
                Task { @MainActor [weak self] in self?.navigateTo(favorite: fav) }
                completion()
            }
            return item
        }
        template.updateSections([CPListSection(items: items)])
    }

    private func navigateTo(favorite: FavoriteEntity) {
        let coord = CLLocationCoordinate2D(latitude: favorite.latitude, longitude: favorite.longitude)
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        dest.name = favorite.name
        dest.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func formatPower(_ kw: Double) -> String {
        let fractional = kw.truncatingRemainder(dividingBy: 1)
        let str = fractional < 0.05 ? String(format: "%.0f", kw) : String(format: "%.1f", kw)
        return "\(str) kW"
    }
}
