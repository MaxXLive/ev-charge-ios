//
//  NearbyTemplate.swift
//  evcharge
//
//  CPPointOfInterestTemplate: Karte mit nächstgelegenen Ladestationen.
//

import CarPlay
import CoreLocation
import MapKit
import SwiftUI

@MainActor
final class NearbyTemplate: NSObject {
    let template: CPPointOfInterestTemplate
    private let viewModel: CarPlayViewModel
    private weak var interfaceController: CPInterfaceController?
    private let onSearch: () -> Void
    private var cachedPOIs: [CPPointOfInterest] = []

    init(viewModel: CarPlayViewModel, interfaceController: CPInterfaceController, onSearch: @escaping () -> Void) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController
        self.onSearch = onSearch

        self.template = CPPointOfInterestTemplate(
            title: String(localized: "Ladestationen"),
            pointsOfInterest: [],
            selectedIndex: NSNotFound
        )
        super.init()
        self.template.pointOfInterestDelegate = self
        self.template.tabImage = UIImage(systemName: "bolt.fill")

        let searchButton = CPBarButton(image: UIImage(systemName: "magnifyingglass")!) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onSearch() }
        }
        let filterButton = CPBarButton(image: UIImage(systemName: "line.3.horizontal.decrease.circle")!) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pushFilter() }
        }
        template.leadingNavigationBarButtons = [searchButton]
        template.trailingNavigationBarButtons = [filterButton]

        viewModel.onNearbyUpdated = { [weak self] in
            Task { @MainActor in self?.updatePOIs() }
        }
    }

    private func updatePOIs() {
        let newPOIs = viewModel.nearbyChargers.compactMap { makePOI(for: $0) }
        let oldTitles = cachedPOIs.map { $0.title }
        let newTitles = newPOIs.map { $0.title }
        guard oldTitles != newTitles else { return }
        cachedPOIs = newPOIs
        template.setPointsOfInterest(cachedPOIs, selectedIndex: NSNotFound)
    }

    private func makePOI(for location: ChargeLocation) -> CPPointOfInterest? {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.clLocationCoordinate))
        mapItem.name = location.name

        let subtitle = subtitleFor(location)
        let poi = CPPointOfInterest(
            location: mapItem,
            title: location.name,
            subtitle: subtitle,
            summary: location.address?.formatted,
            detailTitle: location.name,
            detailSubtitle: subtitle,
            detailSummary: location.formatChargepoints(),
            pinImage: Self.pinImage(power: location.maxPower)
        )

        poi.primaryButton = CPTextButton(
            title: String(localized: "Navigieren"),
            textStyle: .normal
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.navigate(to: location) }
        }
        poi.secondaryButton = CPTextButton(
            title: String(localized: "Details"),
            textStyle: .normal
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pushDetail(for: location) }
        }
        return poi
    }

    private func navigate(to location: ChargeLocation) {
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: location.clLocationCoordinate))
        dest.name = location.name
        dest.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func pushDetail(for location: ChargeLocation) {
        guard let interfaceController else { return }
        let detail = DetailTemplate(location: location, viewModel: viewModel, interfaceController: interfaceController)
        interfaceController.pushTemplate(detail.template, animated: true) { _, _ in }
    }

    private func pushFilter() {
        guard let interfaceController else { return }
        let filter = FilterTemplate(viewModel: viewModel, interfaceController: interfaceController)
        interfaceController.pushTemplate(filter.template, animated: true) { _, _ in }
    }

    private func subtitleFor(_ loc: ChargeLocation) -> String {
        var parts: [String] = []
        if let max = loc.maxPower { parts.append(formatPower(max)) }
        if let net = loc.network { parts.append(net) }
        return parts.joined(separator: " · ")
    }

    private func formatPower(_ kw: Double) -> String {
        let fractional = kw.truncatingRemainder(dividingBy: 1)
        let str = fractional < 0.05 ? String(format: "%.0f", kw) : String(format: "%.1f", kw)
        return "\(str) kW"
    }

    private static func pinImage(power: Double?) -> UIImage {
        let renderer = ImageRenderer(content: ChargerPinView(power: power, size: 36))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - CPPointOfInterestTemplateDelegate

extension NearbyTemplate: CPPointOfInterestTemplateDelegate {
    nonisolated func pointOfInterestTemplate(
        _ template: CPPointOfInterestTemplate,
        didChangeMapRegion region: MKCoordinateRegion
    ) {
        let center = region.center
        Task { @MainActor in
            self.viewModel.setSearchCenter(center)
        }
    }

    nonisolated func pointOfInterestTemplate(
        _ template: CPPointOfInterestTemplate,
        didSelectPointOfInterest pointOfInterest: CPPointOfInterest
    ) {}
}
