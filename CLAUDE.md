# EVMap iOS

Native iOS/SwiftUI port of [EVMap](https://ev-map.app) (Android, MIT License, Copyright Johan von Forstner). Finds EV charging stations using GoingElectric, Open Charge Map, and Nobil as data sources. Ad-free, non-commercial, open source.

## Build, Install & Launch (Simulator)

**After every iOS code change: build, install and launch on the simulator.**

```bash
DEV="D93EB764-DF6D-4D05-85C6-AA45AC05EE38"
APP_ID="de.ermackov.evmap"
APP_PATH="/Users/MERMACK/Library/Developer/Xcode/DerivedData/evmap-fpsqgrxlaoowohdhjbgmbyjjwbev/Build/Products/Debug-iphonesimulator/evmap.app"

# Build
cd /Users/MERMACK/Projects/evmap-ios/evmap  # Xcode project is in evmap/ subdirectory
xcodebuild -scheme evmap -destination "id=$DEV" -configuration Debug 2>&1 | grep -E "error:|BUILD"

# Install & Launch
xcrun simctl terminate "$DEV" "$APP_ID" 2>/dev/null
xcrun simctl install "$DEV" "$APP_PATH"
xcrun simctl spawn "$DEV" defaults write "$APP_ID" onboardingDone -bool YES  # skip onboarding in dev
xcrun simctl launch "$DEV" "$APP_ID"
```

**Target:** iPhone 17 Pro (`D93EB764-DF6D-4D05-85C6-AA45AC05EE38`)  
**Bundle ID:** `de.ermackov.evmap`  
**DerivedData:** `evmap-fpsqgrxlaoowohdhjbgmbyjjwbev`  
**Deployment target:** iOS 26.2  
**Xcode:** 26.3  

### Simulator interaction (idb)

```bash
idb ui tap --udid "$DEV" X Y          # tap at logical coordinates (screen: 402×874)
idb ui swipe --udid "$DEV" x1 y1 x2 y2
idb ui describe-all --udid "$DEV"     # accessibility tree with AXLabel + frame
```

## API Keys

Keys live in `evmap/Secrets.plist` (gitignored). Copy from `Secrets.example.plist`:

| Key | Source |
|-----|--------|
| `GOINGELECTRIC_API_KEY` | Request at goingelectric.de |
| `OPENCHARGEMAP_API_KEY` | Request at openchargemap.org |
| `NOBIL_API_KEY` | Request at nobil.no |

Do NOT commit `Secrets.plist`. If a clean build doesn't pick up key changes, run `xcodebuild clean` first.

## Android Reference

The Android source (EVMap) is cloned at `evmap-ios/input/EVMap` (read-only reference). Useful for checking original API models, filter definitions, and color values.

## Architecture

### Project structure

```
evmap/evmap/
├── evmapApp.swift          # Entry point, SwiftData container
├── ContentView.swift       # TabView (Karte / Favoriten / Einstellungen), onboarding
├── Core/
│   ├── AppState.swift      # @MainActor @Observable — selected tab, map target
│   ├── ChargepointAPI.swift # Protocol + shared helpers (powerSteps, clustering)
│   ├── DataSource.swift    # DataSourceID enum, selectedSet, supportedFilterKeys
│   ├── LocationManager.swift
│   ├── Resource.swift      # enum Resource<T> — loading/success/error
│   ├── SearchCompleter.swift
│   └── Secrets.swift       # Loads Secrets.plist from bundle
├── Models/
│   ├── ChargeLocation.swift  # ChargeLocation, Coordinate, Address, Cost, OpeningHours…
│   ├── Chargepoint.swift     # Chargepoint + Connector constants
│   ├── Filters.swift         # Filter enum, FilterValue, FilterWithValue
│   ├── FilterValueDTO.swift  # Codable DTO for profile persistence
│   └── Persistence/
│       ├── FavoriteEntity.swift      # SwiftData @Model
│       └── FilterProfileEntity.swift # SwiftData @Model
├── API/
│   ├── GoingElectric/        # GEModels.swift, GoingElectricAPI.swift
│   ├── OpenChargeMap/        # OCMModels.swift, OpenChargeMapAPI.swift
│   ├── Nobil/                # NobilModels.swift, NobilAPI.swift
│   ├── Availability/         # Availability.swift, EnBwAvailabilityDetector.swift, AvailabilityService.swift
│   └── Chargeprice/          # Chargeprice.swift
├── ViewModels/
│   └── MapViewModel.swift    # @MainActor @Observable — multi-source loading, clustering, filters
└── Views/
    ├── MapView.swift
    ├── ChargerDetailView.swift
    ├── ChargerPinView.swift / ChargerStyle.swift
    ├── FilterView.swift
    ├── DataSourcePicker.swift
    ├── FavoritesView.swift
    ├── SettingsView.swift
    ├── OnboardingView.swift
    ├── PhotoGalleryView.swift
    └── ChargeCardsListView.swift
```

### Key patterns

- **`@Observable` + `@MainActor`** on all ViewModels. Pure value types (`struct`/`enum`) are `nonisolated`.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`** (both build configs) — prevents value types from inheriting MainActor isolation, which would break actor-boundary access.
- **`ChargepointAPI` protocol** abstracts data sources. `MapViewModel` holds `[any ChargepointAPI]` and queries all in parallel via `withTaskGroup`.
- **Multi-source**: `DataSourceID.selectedSet` (comma-separated string in `UserDefaults("dataSources")`). `MapViewModel.updateAPIs()` called on change. Client-side clustering for non-GE sources (`clientCluster()`). GE server clusters are preserved.
- **Filter intersection**: `availableFilters` is union of all active sources. `DataSourceID.supportedFilterKeys` (hardcoded) drives `partiallyUnsupportedFilters` — unsupported rows shown greyed with ⓘ info button.
- **Reference data**: cached per-API in `referenceDataMap: [String: ReferenceData]`. GE ref data keyed `"goingelectric"` — always look up explicitly (not `apis.first`) when casting to `GEReferenceData`.
- **Availability**: `EnBwAvailabilityDetector` (actor) — GE + DACH/EU only, forces `Accept-Language: de-DE` (EnBW localizes plug names; English gives "Type 2" instead of "Typ 2" breaking matching).
- **Photos**: `ChargerPhoto.Source` enum — `.goingElectric(baseURL:)`, `.openChargeMap(thumb:large:)`, `.simple(small:large:)`.
- **Translation**: `import Translation` — `.translationPresentation(isPresented:text:)` on detail view for free-text fields (amenities, generalInformation, locationDescription).

### Known quirks / past bugs

| Source | Quirk |
|--------|-------|
| GE | `photos`/`chargecards` can be `false` instead of `[]` in JSON — use `StringOrFalse`/custom decoders. `GEChargerPhoto.id` is `Int` not `String`. |
| GE | Filter params use `ChoiceResult` enum (`.empty`/`.value`) to avoid triple-optional. |
| OCM | `getChargepoints` fails if `referenceData` is wrong type — always call `loadReferenceDataIfNeeded()` first. |
| Nobil | `Position` field is string `"(lat, lng)"`. `attrval` can be String, Int, or Double. IDs are `"NOR_1234"` → `getChargepointDetail` unsupported. |
| EnBW | Plug names are language-dependent — force `Accept-Language: de-DE`. |
| Multi-source | `clientCluster` skips re-clustering if `hasServerClusters` — fixed to keep GE clusters and cluster only locations. |

## Versioning & Commit Messages

Version and build number live in `evmap.xcodeproj/project.pbxproj`:
- **`MARKETING_VERSION`** — App version (e.g. `0.1.0`)
- **`CURRENT_PROJECT_VERSION`** — Build number (e.g. `1`)

Both values appear **twice** in `project.pbxproj` (Debug + Release) — always update both occurrences.

### Rules

| Change type | What to increment | Example |
|---|---|---|
| **Bugfix** | Build number only | build `1` → `2` |
| **Minor feature** | Patch version + build number | `0.1.0` → `0.1.1`, build `1` → `2` |
| **New feature area** | Minor version + build number | `0.1.0` → `0.2.0`, build `1` → `2` |

### Commit message format

```
iOS [v0.1.0 (1)] feat: initial release with GE, OCM, Nobil data sources
iOS [v0.1.1 (2)] fix: cluster logic broken with multiple sources active
iOS [v0.2.0 (3)] feat: add real-time availability for OCM stations
```

Format: `iOS [vMAJOR.MINOR.PATCH (BUILD)] <conventional commit message>`

### Workflow

**Bump version ONLY immediately before the commit — never during iterative work.**

1. Make code changes (iterate freely — build/install without bumping)
2. Determine change type (bugfix / minor feature / new feature)
3. Update `MARKETING_VERSION` and/or `CURRENT_PROJECT_VERSION` in `project.pbxproj` (both Debug + Release sections)
4. Update `CHANGELOG.md` — add entry for this version
5. Stage all changes including `project.pbxproj` and `CHANGELOG.md`
6. Commit with versioned prefix

**Do not commit a version bump alone** — bump and change go in the same commit.
