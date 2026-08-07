# Changelog — EV Charge iOS

Release notes for each version.

---

## v1.1.0 (Build 16)

**Rebrand: EVMap → EV Charge**

- Renamed the app from "EVMap" to "EV Charge" (trademark resolution with Johan von Forstner, Apple ref APP273415): home-screen name, App Store name & subtitle (11 languages), in-app text
- New, distinct app icon (Type 2 connector, full-bleed with a subtle gradient) + WelcomeLogo; removed the old EVMap icon/logo (incl. the unused AppLogo asset)
- Attribution to the original: in-app credits (EVMap, Johan von Forstner, MIT) plus a line in all store descriptions ("Based on EVMap by Johan von Forstner, MIT License")
- Domain → `ev-charge.ermackov.de`, repo → `MaxXLive/ev-charge-ios`
- Marketing website fully rebranded (copy in 12 languages, wordmark, metadata, favicon) — attribution to the Android original intentionally preserved

---

## v1.0.0 (Build 14)

**App Store rejection fixes**

- Localized location permission prompt (InfoPlist.xcstrings, 11 languages) instead of hardcoded German
- Reworked App Store descriptions: all 10 languages — added Nobil, added Tesla feature, removed OpenStreetMap/Chargeprice/Android/Material-Design leftovers, cleaned up duplicate GitHub links
- Updated support URL to `https://ev-charge.ermackov.de/support` (working support page)

---

## v1.0.0 (Build 13)

**Apple CarPlay (enabled)**

- Apple CarPlay fully enabled after approval of the `com.apple.developer.carplay-charging` entitlement
- Charging map, station details, navigation, favorites, search and filter profiles directly on the car display

---

## v1.0.0 (Build 10)

**Licenses & Credits**

- Expanded the Licenses & Credits page: attribution for all data sources (Open Charge Map CC BY-SA 4.0, NOBIL, Chargeprice), Apple Maps/MapKit and EnBW availability
- Added own copyright (Max Ermackov, MIT) with a GitHub link
- Note that no external third-party libraries are used
- All new text translated into all 11 languages

---

## v1.0.0 (Build 9)

**Features**

- Apple CarPlay support: nearby charger map, station detail, navigation, favorites list, place search, and saved filter profiles — all directly on the car display
- Colored teardrop pin markers in CarPlay (matching phone app: power-based color coding)
- CarPlay onboarding page in the setup wizard
- App Store descriptions updated in all 10 languages to mention CarPlay

---

## v0.4.0 (Build 8)

**Features**

- fastlane automation for App Store Connect: build, upload metadata, screenshots and binary in one command
- Localized App Store metadata in 10 languages (cs, de, en, fr, it, nl, no, pt, ro, sv) with descriptions, keywords, subtitles and release notes
- Automated screenshot pipeline: snapshot captures 3 screens (map, station detail, filter sheet) in all 10 languages, frameit adds the official iPhone 17 Pro device frame, and pad_framed.sh pads to the required 1290x2796 canvas
- UITest target (evmapUITests) with deterministic screenshot flow: Stuttgart city center, HPC Ladepark detail, filter sheet
- Screenshot mode in MapView: pins map to Stuttgart at a tight zoom and opens detail sheet at full height when FASTLANE_SNAPSHOT is set

---

## v0.3.2 (Build 7)

**Features**

- Scrubbing on the Tesla average-utilization chart: drag across the graph to read the utilization for each hour (e.g. "12:00: 13 %")
- Loading placeholder for Tesla real-time data: when signed in and viewing a Tesla Supercharger, a skeleton with a spinner reserves space while data loads, so the layout no longer jumps when it arrives

**Fixes**

- Leave headroom above the utilization chart so the scrubbing bubble no longer overlaps the section heading

---

## v0.3.1 (Build 5)

**Features**

- Tapping a map cluster now zooms into it, expanding it into individual stations

**Localization**

- Added translations for all Tesla strings (login, pricing tiers, utilization, prompts) across the 11 supported languages

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
