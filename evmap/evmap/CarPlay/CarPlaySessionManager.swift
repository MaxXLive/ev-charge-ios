//
//  CarPlaySessionManager.swift
//  evmap
//
//  Verwaltet die CarPlay-Template-Hierarchie und hält den ViewModel am Leben.
//

import CarPlay

@MainActor
final class CarPlaySessionManager {
    private let interfaceController: CPInterfaceController
    let viewModel: CarPlayViewModel

    private var nearbyTemplate: NearbyTemplate?
    private var favoritesTemplate: FavoritesTemplate?
    private var searchTemplate: SearchTemplate?

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.viewModel = CarPlayViewModel()
    }

    func start() {
        let search = SearchTemplate(viewModel: viewModel, interfaceController: interfaceController)
        let nearby = NearbyTemplate(viewModel: viewModel, interfaceController: interfaceController) { [weak interfaceController] in
            interfaceController?.pushTemplate(search.template, animated: true) { _, _ in }
        }
        let favorites = FavoritesTemplate(viewModel: viewModel, interfaceController: interfaceController)

        self.nearbyTemplate = nearby
        self.favoritesTemplate = favorites
        self.searchTemplate = search

        let tabBar = CPTabBarTemplate(templates: [
            nearby.template,
            favorites.template,
        ])

        interfaceController.setRootTemplate(tabBar, animated: false) { _, _ in }

        Task {
            await viewModel.start()
        }
    }

    func stop() {
        viewModel.stop()
    }
}
