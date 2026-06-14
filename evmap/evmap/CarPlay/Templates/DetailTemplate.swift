//
//  DetailTemplate.swift
//  evmap
//
//  CPInformationTemplate: Detailansicht einer Ladestation.
//

import CarPlay
import MapKit

@MainActor
final class DetailTemplate {
    let template: CPInformationTemplate
    private let viewModel: CarPlayViewModel
    private var location: ChargeLocation
    private weak var interfaceController: CPInterfaceController?

    init(location: ChargeLocation, viewModel: CarPlayViewModel, interfaceController: CPInterfaceController) {
        self.location = location
        self.viewModel = viewModel
        self.interfaceController = interfaceController

        self.template = CPInformationTemplate(
            title: location.name,
            layout: .leading,
            items: Self.buildItems(for: location),
            actions: []
        )
        self.template.actions = buildActions()

        if !location.isDetailed {
            Task { await self.loadDetail() }
        }
    }

    private static func buildItems(for loc: ChargeLocation) -> [CPInformationItem] {
        var items: [CPInformationItem] = []
        if let address = loc.address?.formatted {
            items.append(CPInformationItem(title: String(localized: "Adresse"), detail: address))
        }
        let chargepoints = loc.formatChargepoints()
        if !chargepoints.isEmpty {
            items.append(CPInformationItem(title: String(localized: "Ladepunkte"), detail: chargepoints))
        }
        if let network = loc.network {
            items.append(CPInformationItem(title: String(localized: "Netzwerk"), detail: network))
        }
        if let op = loc.operator {
            items.append(CPInformationItem(title: String(localized: "Betreiber"), detail: op))
        }
        if let cost = loc.cost?.descriptionShort, !cost.isEmpty {
            items.append(CPInformationItem(title: String(localized: "Kosten"), detail: cost))
        }
        return items
    }

    private func buildActions() -> [CPTextButton] {
        let isFav = viewModel.isFavorite(id: location.id, dataSource: location.dataSource)
        return [
            CPTextButton(
                title: String(localized: "Navigieren"),
                textStyle: .confirm
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.navigate() }
            },
            CPTextButton(
                title: isFav ? String(localized: "Favorit entfernen") : String(localized: "Als Favorit"),
                textStyle: .normal
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.viewModel.toggleFavorite(location: self.location)
                    self.template.actions = self.buildActions()
                }
            }
        ]
    }

    private func navigate() {
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: location.clLocationCoordinate))
        dest.name = location.name
        dest.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func loadDetail() async {
        guard let detailed = await viewModel.loadDetail(for: location) else { return }
        location = detailed
        template.items = Self.buildItems(for: detailed)
        template.actions = buildActions()
    }
}
