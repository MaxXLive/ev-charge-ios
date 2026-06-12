//
//  ChargerDetailView.swift
//  evmap
//
//  Detail-Ansicht einer Ladestation (Android-Pendant: Bottom-Sheet in MapFragment).
//

import MapKit
import SwiftData
import SwiftUI
import Translation

struct ChargerDetailView: View {
    /// Anfangsdaten (ggf. nur Kurzform aus der Liste).
    let location: ChargeLocation
    let model: MapViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var favorites: [FavoriteEntity]

    /// Vollständige Daten nach Nachladen.
    @State private var detailed: ChargeLocation?
    /// Echtzeit-Verfügbarkeit (falls eine Quelle Daten liefert).
    @State private var availability: ChargeLocationStatus?
    /// Aktuell im Hero gezeigtes Foto.
    @State private var heroIndex = 0
    /// Vollbild-Galerie offen.
    @State private var showGallery = false
    /// Läuft gerade ein manuelles Neu-Laden.
    @State private var isReloading = false
    /// Text der gerade übersetzt wird (Translation-Sheet).
    @State private var translationText: String? = nil

    init(location: ChargeLocation, model: MapViewModel) {
        self.location = location
        self.model = model
        let id = location.id
        let source = location.dataSource
        _favorites = Query(filter: #Predicate { $0.chargerId == id && $0.dataSource == source })
    }

    private var current: ChargeLocation { detailed ?? location }
    private var isFavorite: Bool { !favorites.isEmpty }

    private var shareURL: URL? { current.url.flatMap { URL(string: $0) } }
    private var editURL: URL? { current.editUrl.flatMap { URL(string: $0) } }

    /// Anzeigename der Datenquelle dieser Station.
    private var dataSourceName: String {
        switch current.dataSource {
        case "goingelectric": return "GoingElectric"
        case "openchargemap": return "Open Charge Map"
        case "nobil": return "NOBIL"
        case "openstreetmap": return "OpenStreetMap"
        default: return "Datenquelle"
        }
    }

    private var geReferenceData: GEReferenceData? {
        model.referenceDataMap["goingelectric"] as? GEReferenceData
    }

    /// Ladekarten-Namen aus den Referenzdaten (id → name).
    private var chargeCardNames: [String: String] {
        guard let ref = geReferenceData else { return [:] }
        return Dictionary(uniqueKeysWithValues: ref.chargecards.map { (String($0.id), $0.name) })
    }

    /// Akzeptierte Ladekarten dieser Station (volle Objekte aus den Referenzdaten), sortiert.
    private var acceptedCards: [GEChargeCard] {
        guard let ref = geReferenceData,
              let ids = current.chargecards else { return [] }
        let idSet = Set(ids.map { $0.id })
        return ref.chargecards.filter { idSet.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let photos = current.photos, !photos.isEmpty {
                        photoHero(photos)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        connectorsSection
                        if let cost = current.cost, !cost.isEmpty {
                            costSection(cost)
                        }
                        if let hours = current.openinghours, !hours.isEmpty {
                            openingHoursSection(hours)
                        }
                        if let op = current.operator, !op.isEmpty {
                            section("Betreiber", systemImage: "building.2") { Text(op) }
                        }
                        if let amenities = current.amenities, !amenities.isEmpty {
                            section("Ausstattung", systemImage: "list.bullet") {
                                textWithTranslate(amenities)
                            }
                        }
                        if let info = current.generalInformation, !info.isEmpty {
                            section("Weitere Informationen", systemImage: "text.alignleft") {
                                textWithTranslate(info)
                            }
                        }
                        chargeCardsSection
                        if let desc = current.locationDescription, !desc.isEmpty {
                            section("Hinweise", systemImage: "info.circle") {
                                textWithTranslate(desc)
                            }
                        }
                        actions
                        coordinatesFooter
                        licenseFooter
                    }
                    .padding()
                }
            }
            .translationPresentation(
                isPresented: Binding(
                    get: { translationText != nil },
                    set: { if !$0 { translationText = nil } }
                ),
                text: translationText ?? ""
            )
            .overlay(alignment: .top) {
                if isReloading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Aktualisiere…").font(.footnote)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isReloading)
            .navigationTitle(current.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .accessibilityLabel(isFavorite ? "Favorit entfernen" : "Als Favorit speichern")

                    if let share = shareURL {
                        ShareLink(item: share, subject: Text(current.name)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    Menu {
                        if let edit = editURL {
                            Button {
                                openURL(edit)
                            } label: {
                                Label("Bei \(dataSourceName) bearbeiten", systemImage: "pencil")
                            }
                        }
                        Button {
                            Task { await reload() }
                        } label: {
                            Label("Neu laden", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .task {
                if !current.isDetailed {
                    detailed = await model.loadDetail(for: location)
                }
                availability = await model.loadAvailability(for: current)
            }
            .fullScreenCover(isPresented: $showGallery) {
                PhotoGalleryView(photos: current.photos ?? [], initialIndex: heroIndex)
            }
        }
    }

    // MARK: - Foto-Hero

    private func photoHero(_ photos: [ChargerPhoto]) -> some View {
        TabView(selection: $heroIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                AsyncImage(url: photo.url(width: 800)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        ProgressView()
                    }
                }
                .clipped()
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { showGallery = true }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Abschnitte

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let network = current.network {
                    Text(network).font(.subheadline.weight(.medium))
                }
                if current.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                Spacer()
            }
            if let address = current.address {
                Label(address.formatted, systemImage: "mappin.and.ellipse")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if current.faultReport != nil {
                Label("Störung gemeldet", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    private var connectorsSection: some View {
        section("Anschlüsse", systemImage: "ev.charger") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(current.chargepointsMerged.enumerated()), id: \.offset) { _, cp in
                    HStack(spacing: 12) {
                        Image(Chargepoint.Connector.iconName(for: cp.type))
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(ChargerStyle.color(forPower: cp.power))
                        // Leistung zuerst (auf den ersten Blick wichtiger), Steckertyp rechts.
                        Text("\(cp.count) × \(cp.formatPower() ?? "—")")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            availabilityBadge(cp)
                            Text(Chargepoint.Connector.displayName(for: cp.type))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let av = availability {
                    Label(realtimeSourceText(av), systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder private func availabilityBadge(_ cp: Chargepoint) -> some View {
        if let entry = availabilityEntry(for: cp), entry.anyKnown {
            HStack(spacing: 4) {
                Circle().fill(entry.color).frame(width: 8, height: 8)
                Text("\(entry.availableCount)/\(entry.total) frei")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.color)
            }
        }
    }

    private func availabilityEntry(for cp: Chargepoint) -> AvailabilityEntry? {
        availability?.entries.first {
            $0.chargepoint.type == cp.type && $0.chargepoint.power == cp.power
        }
    }

    private func realtimeSourceText(_ av: ChargeLocationStatus) -> String {
        var text = "Echtzeit-Daten: \(av.source)"
        if let last = av.lastChange {
            let fmt = RelativeDateTimeFormatter()
            fmt.locale = Locale(identifier: "de_DE")
            text += " · aktualisiert \(fmt.localizedString(for: last, relativeTo: .now))"
        }
        return text
    }

    private func costSection(_ cost: Cost) -> some View {
        section("Kosten", systemImage: "eurosign.circle") {
            VStack(alignment: .leading, spacing: 4) {
                if let fc = cost.freecharging {
                    Text(fc ? "⚡ Laden kostenlos" : "⚡ Laden kostenpflichtig")
                }
                if let fp = cost.freeparking {
                    Text(fp ? "🅿️ Parken kostenlos" : "🅿️ Parken kostenpflichtig")
                }
                if let d = cost.descriptionLong ?? cost.descriptionShort {
                    Text(d).foregroundStyle(.secondary).font(.footnote)
                }
            }.font(.callout)
        }
    }

    private func openingHoursSection(_ hours: OpeningHours) -> some View {
        section("Öffnungszeiten", systemImage: "clock") {
            if hours.twentyfourSeven {
                Text("24 Stunden geöffnet")
            } else if let days = hours.days {
                VStack(alignment: .leading, spacing: 2) {
                    dayRow("Mo", days.monday)
                    dayRow("Di", days.tuesday)
                    dayRow("Mi", days.wednesday)
                    dayRow("Do", days.thursday)
                    dayRow("Fr", days.friday)
                    dayRow("Sa", days.saturday)
                    dayRow("So", days.sunday)
                }.font(.callout.monospacedDigit())
            } else if let desc = hours.description {
                Text(desc)
            }
        }
    }

    private func dayRow(_ label: String, _ hours: Hours?) -> some View {
        HStack {
            Text(label).frame(width: 28, alignment: .leading).foregroundStyle(.secondary)
            Text(hours?.description ?? "geschlossen")
            Spacer()
        }
    }

    @ViewBuilder private var chargeCardsSection: some View {
        if let cards = current.chargecards, !cards.isEmpty {
            section("Ladekarten", systemImage: "creditcard") {
                VStack(alignment: .leading, spacing: 8) {
                    if current.barrierFree == true {
                        Label("Ohne Vertrag / Registrierung nutzbar", systemImage: "checkmark.circle")
                            .font(.callout).foregroundStyle(.green)
                    }
                    if acceptedCards.isEmpty {
                        // Referenzdaten (noch) nicht geladen – nur Anzahl.
                        Text("\(cards.count) kompatible Ladekarten")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        NavigationLink {
                            ChargeCardsListView(cards: acceptedCards)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(acceptedCards.count) kompatible Ladekarten")
                                        .font(.callout)
                                    Text(acceptedCards.prefix(4).map(\.name).joined(separator: ", ") + " …")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                openInMaps()
            } label: {
                Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if Chargeprice.isSupported(current), let url = Chargeprice.poiURL(for: current) {
                Button {
                    openURL(url)
                } label: {
                    Label("Preisvergleich", systemImage: "eurosign.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            if let urlString = current.viewURL, let url = URL(string: urlString) {
                Button {
                    openURL(url)
                } label: {
                    Label("Bei \(dataSourceName) ansehen", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if let urlString = current.sourceURL, let url = URL(string: urlString) {
                Button {
                    openURL(url)
                } label: {
                    Label("Quelle: \(dataSourceName)", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 4)
    }

    private var coordinatesFooter: some View {
        Text(String(format: "%.5f, %.5f", current.coordinates.lat, current.coordinates.lng))
            .font(.caption2.monospaced())
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    /// Lizenz-/Quellenangabe (z.B. für Open Charge Map / Bundesnetzagentur CC-BY erforderlich).
    @ViewBuilder private var licenseFooter: some View {
        if let license = current.license, !license.isEmpty {
            Text(license)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// Text mit „Übersetzen"-Button. Öffnet Apple Translation Sheet.
    private func textWithTranslate(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
            Button {
                translationText = text
            } label: {
                Label("Übersetzen", systemImage: "translate")
                    .font(.caption)
            }
            .foregroundStyle(.tint)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bausteine

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Aktionen

    private func toggleFavorite() {
        if let existing = favorites.first {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteEntity(from: current))
        }
    }

    /// Detail- und Verfügbarkeitsdaten (Echtzeit) zusammen neu laden.
    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        if let fresh = await model.loadDetail(for: location) {
            detailed = fresh
        }
        availability = await model.loadAvailability(for: current)
        isReloading = false
    }

    private func openInMaps() {
        let coord = CLLocation(latitude: current.coordinates.lat, longitude: current.coordinates.lng)
        let item = MKMapItem(location: coord, address: nil)
        item.name = current.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
