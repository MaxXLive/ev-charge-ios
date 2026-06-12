//
//  MapView.swift
//  evmap
//

import MapKit
import SwiftUI

/// Identifizierbares Wrapper-Element für die Karte (Station oder Cluster).
private struct MapEntry: Identifiable {
    let id: String
    let item: ChargepointListItem

    init(_ item: ChargepointListItem) {
        self.item = item
        switch item {
        case let .location(loc): id = loc.stableId
        case let .cluster(cluster): id = "cluster:\(cluster.coordinates.lat),\(cluster.coordinates.lng)"
        }
    }
}

struct MapView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @State private var model = MapViewModel()
    @State private var searchCompleter = SearchCompleter()
    @State private var camera: MapCameraPosition = .region(Self.fallbackRegion)
    @State private var lastRegion: MKCoordinateRegion?
    @State private var didCenterOnUser = false
    @State private var showFilters = false
    @State private var mapStyleOption: MapStyleOption = .standard
    @AppStorage("dataSources") private var dataSourcesRaw: String = ""

    // Fallback: München, falls (noch) kein Standort.
    private static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.137, longitude: 11.575),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )

    private var entries: [MapEntry] {
        (model.chargers.value?.items ?? []).map { MapEntry($0) }
    }

    private var isLocationAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
    }

    /// Karten-Steuerung unten rechts (Kartentyp + Standort) im Liquid-Glass-Stil.
    private var mapButtons: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                mapStyleButton
                locateButton
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 28)
    }

    private var mapStyleButton: some View {
        Menu {
            Picker("Kartentyp", selection: $mapStyleOption) {
                ForEach(MapStyleOption.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel("Kartentyp")
    }

    private var locateButton: some View {
        Button {
            locateMe()
        } label: {
            Image(systemName: isLocationAuthorized ? "location.fill" : "location")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel("Zu meinem Standort")
    }

    private func locateMe() {
        guard isLocationAuthorized else {
            locationManager.request()
            return
        }
        guard let coord = locationManager.currentLocation else {
            locationManager.request()
            return
        }
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                if isLocationAuthorized {
                    UserAnnotation()
                }
                ForEach(entries) { entry in
                    switch entry.item {
                    case let .location(loc):
                        Annotation(loc.name, coordinate: loc.clLocationCoordinate, anchor: .bottom) {
                            ChargerMarker(location: loc) { model.selected = loc }
                        }
                    case let .cluster(cluster):
                        Annotation("", coordinate: cluster.coordinates.clLocationCoordinate) {
                            ClusterMarker(count: cluster.clusterCount) {
                                zoomIntoCluster(cluster)
                            }
                        }
                    }
                }
            }
            .mapStyle(mapStyleOption.style)
            .mapControls {
                MapCompass()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                lastRegion = context.region
                searchCompleter.setRegion(context.region)
                model.onRegionChange(context.region)
            }
            .overlay(alignment: .top) { statusBar }
            .overlay(alignment: .bottomTrailing) { mapButtons }
            .searchable(text: searchQueryBinding, prompt: "Ort suchen")
            .searchSuggestions { searchSuggestions }
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: model.activeFilterCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView(model: model)
            }
            .onChange(of: model.filterVersion) {
                if let region = lastRegion { model.reload(region: region) }
            }
            .onChange(of: dataSourcesRaw) {
                model.updateAPIs()
                if let region = lastRegion { model.reload(region: region) }
            }
            .sheet(item: $model.selected) { loc in
                ChargerDetailView(location: loc, model: model)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .task {
                await model.loadReferenceDataIfNeeded()
            }
            .onChange(of: locationManager.currentLocation?.latitude) {
                centerOnUserOnce()
            }
            .onChange(of: appState.mapTarget) {
                centerOnTarget()
            }
        }
    }

    // MARK: - Suche

    private var searchQueryBinding: Binding<String> {
        Binding(get: { searchCompleter.query }, set: { searchCompleter.query = $0 })
    }

    @ViewBuilder private var searchSuggestions: some View {
        ForEach(searchCompleter.suggestions, id: \.self) { suggestion in
            Button {
                selectSuggestion(suggestion)
            } label: {
                VStack(alignment: .leading) {
                    Text(suggestion.title)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        Task {
            guard let coord = await searchCompleter.resolve(suggestion) else { return }
            searchCompleter.query = ""
            withAnimation {
                camera = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }

    private func centerOnTarget() {
        guard let target = appState.mapTarget else { return }
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: target.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        appState.mapTarget = nil
    }

    @ViewBuilder private var statusBar: some View {
        if model.chargers.isLoading {
            ProgressView()
                .padding(8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        } else if let msg = model.chargers.errorMessage {
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .padding(8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        } else if !Secrets.hasGoingElectricKey {
            Label("Kein GoingElectric-API-Key – Secrets.plist anlegen.", systemImage: "key.fill")
                .font(.footnote)
                .padding(8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        }
    }

    /// Auf ein Cluster hineinzoomen (zentrieren + Span verkleinern). Der folgende
    /// Kamerawechsel lädt die Charger neu und löst das Cluster auf.
    private func zoomIntoCluster(_ cluster: ChargeLocationCluster) {
        let currentSpan = lastRegion?.span ?? Self.fallbackRegion.span
        let factor = 3.0
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(currentSpan.latitudeDelta / factor, 0.002),
            longitudeDelta: max(currentSpan.longitudeDelta / factor, 0.002)
        )
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: cluster.coordinates.clLocationCoordinate,
                span: newSpan
            ))
        }
    }

    private func centerOnUserOnce() {
        guard !didCenterOnUser, let coord = locationManager.currentLocation else { return }
        didCenterOnUser = true
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
}

// MARK: - Marker

private struct ChargerMarker: View {
    let location: ChargeLocation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ChargerPinView(
                power: location.maxPower,
                size: 34,
                hasFault: location.faultReport != nil
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ClusterMarker: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 36, minHeight: 36)
                .background(Circle().fill(.blue.opacity(0.85)))
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kartentyp

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard, satellite, hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .satellite: return String(localized: "Satellit")
        case .hybrid: return String(localized: "Hybrid")
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas.fill"
        case .hybrid: return "globe.americas"
        }
    }

    var style: MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}
