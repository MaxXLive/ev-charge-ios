//
//  Secrets.swift
//  evmap
//
//  Lädt API-Keys aus einer gitignorierten `Secrets.plist` im App-Bundle.
//  Vorlage: `Secrets.example.plist` (umbenennen zu `Secrets.plist` und Key eintragen).
//

import Foundation

enum Secrets {
    private static let values: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(
                from: data, format: nil
            ) as? [String: String]
        else { return [:] }
        return dict
    }()

    /// API-Key für GoingElectric.de. Anzufragen unter https://www.goingelectric.de/.
    static var goingElectricKey: String {
        values["GOINGELECTRIC_API_KEY"] ?? ""
    }

    static var hasGoingElectricKey: Bool { !goingElectricKey.isEmpty }

    /// API-Key für Open Charge Map. Kostenlos unter https://openchargemap.org/site/profile/applications.
    static var openChargeMapKey: String {
        values["OPENCHARGEMAP_API_KEY"] ?? ""
    }

    static var hasOpenChargeMapKey: Bool { !openChargeMapKey.isEmpty }

    /// API-Key für Nobil (Skandinavien). Kostenlos anzufragen unter https://nobil.no/.
    static var nobilKey: String {
        values["NOBIL_API_KEY"] ?? ""
    }

    static var hasNobilKey: Bool { !nobilKey.isEmpty }

    /// EnBW Mobility+ API subscription key. Anzufragen oder aus EVMap Android (MIT) entnehmen.
    static var enBwSubscriptionKey: String {
        values["ENBW_SUBSCRIPTION_KEY"] ?? ""
    }
}
