//
//  SearchCompleter.swift
//  evmap
//
//  Orts-Autovervollständigung über MKLocalSearchCompleter (nativ, kein API-Key).
//  Android-Pendant: Mapbox/Google-Places-Autocomplete.
//

import MapKit
import Observation

@MainActor
@Observable
final class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()

    var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    var suggestions: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Begrenzt Vorschläge geografisch auf den aktuell sichtbaren Bereich.
    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    /// Löst einen Vorschlag in eine Koordinate auf.
    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        return try? await search.start().mapItems.first?.location.coordinate
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}
