//
//  Chargeprice.swift
//  evcharge
//
//  Preisvergleich-Link (Android-Pendant: api/chargeprice/ChargepriceApi.kt).
//  Hinweis: Chargeprice liefert keine In-App-Preisdaten mehr (Kosten gestiegen) –
//  der Button verlinkt nur noch auf chargeprice.app (öffnet die App, falls installiert).
//

import Foundation

enum Chargeprice {
    /// Quellenkürzel für die Chargeprice-URL.
    private static func dataAdapter(_ dataSource: String) -> String? {
        switch dataSource {
        case "goingelectric": return "going_electric"
        case "openchargemap": return "open_charge_map"
        default: return nil
        }
    }

    /// Deep-Link zu chargeprice.app für diese Station.
    static func poiURL(for location: ChargeLocation) -> URL? {
        guard let adapter = dataAdapter(location.dataSource) else { return nil }
        return URL(string: "https://www.chargeprice.app/?poi_id=\(location.id)&poi_source=\(adapter)")
    }

    /// Heuristik (ohne API-Call), ob Chargeprice voraussichtlich Daten hat.
    static func isSupported(_ location: ChargeLocation) -> Bool {
        guard dataAdapter(location.dataSource) != nil else { return false }
        guard let country = location.chargepriceData?.country, supportedCountries.contains(country) else {
            return false
        }
        // Tesla-Supercharger ausschließen.
        if location.dataSource == "goingelectric", location.network == "Tesla Supercharger" {
            return false
        }
        // Alle Ladepunkte brauchen eine bekannte Leistung.
        return location.chargepoints.allSatisfy { $0.hasKnownPower }
    }

    /// Von Chargeprice unterstützte Länder (GoingElectric-Schreibweise).
    private static let supportedCountries: Set<String> = [
        "Deutschland", "Österreich", "Schweiz", "Frankreich", "Belgien", "Niederlande",
        "Luxemburg", "Dänemark", "Norwegen", "Schweden", "Slowenien", "Kroatien", "Ungarn",
        "Tschechien", "Italien", "Spanien", "Großbritannien", "Irland", "Finnland", "Lettland",
        "Litauen", "Estland", "Liechtenstein", "Rumänien", "Slowakei", "Polen", "Serbien",
        "Bulgarien", "Kosovo", "Montenegro", "Albanien", "Griechenland",
    ]
}
