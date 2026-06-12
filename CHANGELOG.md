# Changelog — EVMap iOS

Release notes for each version.

---

## v0.3.0 (Build 4)

**Features**

- Tesla Supercharger real-time data, mirroring the Android app:
  - Live stall availability and pricing without login (guest mode)
  - Optional Tesla account login (OAuth2/PKCE) to unlock owner/member pricing and the average utilization graph
  - Inline "Sign in with Tesla" prompt shown on Supercharger details; no Tesla vehicle required
  - Tesla account management (login/logout) in Settings; tokens stored in the Keychain
- Dedicated "Tesla pricing" section in the charger detail view with per-tier rates (Tesla vehicles & members / other customers), time-of-use windows, and blocking fee

---

## v0.2.0 (Build 3)

**Fixes**

- Multiple-choice filters (networks, connectors, charge cards, categories) no longer reset to "All" when navigating back from the selection list — in-progress selections are now preserved

---

## v0.2.0 (Build 2)

**Localization**

- Full app localization in 11 languages: German, English, French, Italian, Dutch, Portuguese, Swedish, Norwegian Bokmål, Czech, Estonian, Romanian
- Translations sourced from the upstream EVMap (Android) project where available; iOS-specific strings translated additionally
- Language follows the system; a new "Language" section in Settings deep-links to the iOS system settings to override the app language individually
- English is the fallback for device languages that aren't bundled

---

## v0.1.0 (Build 1)

**Initial release**

- Map view with color-coded charging station pins (power level: yellow ≥100 kW, orange ≥43 kW, blue ≥20 kW, grey ≥11 kW, blue-grey <11 kW)
- Three data sources selectable: GoingElectric (DACH), Open Charge Map (worldwide), Nobil (Norway/Sweden) — multiple sources can be active simultaneously
- Station detail view: connectors, opening hours, costs, photos, charge cards, operator info
- Real-time availability badges via EnBW for GoingElectric stations (where supported)
- Favorites with distance sorting and tap-to-map
- Filter by connector type, minimum power, min. number of charge points, network, charge cards, and more — filters show which sources support them
- Filter profiles: save, load, and delete custom filter presets
- Location search via Apple Maps autocomplete
- Map styles: standard, satellite, hybrid
- Translate station notes and amenities with Apple's native Translation
- Chargeprice link for price comparison (GoingElectric, where supported)
- Onboarding wizard with pin legend and data source selection
- Dark/light/system appearance, km/mi unit toggle
- MIT license, open source
