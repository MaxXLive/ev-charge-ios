//
//  SearchTemplate.swift
//  evcharge
//
//  CPSearchTemplate: Ortssuche → Ladestationen in der Nähe des Suchergebnisses.
//

import CarPlay
import MapKit

@MainActor
final class SearchTemplate: NSObject {
    let template: CPSearchTemplate
    private let viewModel: CarPlayViewModel
    private weak var interfaceController: CPInterfaceController?
    private let completer = MKLocalSearchCompleter()
    private var completions: [MKLocalSearchCompletion] = []
    private var pendingHandler: (([CPListItem]) -> Void)?

    init(viewModel: CarPlayViewModel, interfaceController: CPInterfaceController) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController
        self.template = CPSearchTemplate()
        super.init()
        self.template.delegate = self
        self.template.tabImage = UIImage(systemName: "magnifyingglass")
        completer.resultTypes = .address
        completer.delegate = self
    }

    private func makeListItems(from completions: [MKLocalSearchCompletion]) -> [CPListItem] {
        completions.prefix(8).enumerated().map { i, result in
            let item = CPListItem(
                text: result.title,
                detailText: result.subtitle.isEmpty ? nil : result.subtitle
            )
            item.userInfo = i as AnyObject
            return item
        }
    }
}

// MARK: - CPSearchTemplateDelegate

extension SearchTemplate: CPSearchTemplateDelegate {
    nonisolated func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        Task { @MainActor in
            guard !searchText.isEmpty else {
                self.completions = []
                self.pendingHandler = nil
                completionHandler([])
                return
            }
            self.pendingHandler = completionHandler
            self.completer.queryFragment = searchText
        }
    }

    nonisolated func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            defer { completionHandler() }
            guard let index = item.userInfo as? Int,
                  index < self.completions.count else { return }
            let completion = self.completions[index]
            let request = MKLocalSearch.Request(completion: completion)
            if let response = try? await MKLocalSearch(request: request).start(),
               let mapItem = response.mapItems.first {
                self.viewModel.setSearchCenter(mapItem.placemark.coordinate)
            }
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension SearchTemplate: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            let results = Array(completer.results.prefix(8))
            self.completions = results
            let handler = self.pendingHandler
            self.pendingHandler = nil
            handler?(self.makeListItems(from: results))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            let handler = self.pendingHandler
            self.pendingHandler = nil
            handler?([])
        }
    }
}
