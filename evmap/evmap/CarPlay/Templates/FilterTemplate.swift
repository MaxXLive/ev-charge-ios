//
//  FilterTemplate.swift
//  evmap
//
//  CPListTemplate: Filter-Profile auswählen.
//

import CarPlay

@MainActor
final class FilterTemplate {
    let template: CPListTemplate
    private let viewModel: CarPlayViewModel
    private weak var interfaceController: CPInterfaceController?

    init(viewModel: CarPlayViewModel, interfaceController: CPInterfaceController) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController

        self.template = CPListTemplate(
            title: String(localized: "Filter"),
            sections: []
        )
        buildList()
    }

    private func buildList() {
        let profiles = viewModel.loadFilterProfiles()
        let currentName = viewModel.activeFilterProfile?.name

        let noFilterItem = CPListItem(
            text: String(localized: "Kein Filter"),
            detailText: currentName == nil ? String(localized: "Aktiv") : nil
        )
        noFilterItem.handler = { [weak self] _, completion in
            self?.viewModel.setFilterProfile(nil)
            self?.buildList()
            completion()
        }

        let profileItems = profiles.map { profile -> CPListItem in
            let isActive = currentName == profile.name
            let item = CPListItem(
                text: profile.name,
                detailText: isActive ? String(localized: "Aktiv") : nil
            )
            item.handler = { [weak self] _, completion in
                self?.viewModel.setFilterProfile(profile)
                self?.buildList()
                completion()
            }
            return item
        }

        let section = CPListSection(items: [noFilterItem] + profileItems)
        template.updateSections([section])
    }
}
