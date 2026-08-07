import XCTest

// UI test driven by fastlane snapshot. Captures one screenshot per language:
//   01Map           — Stuttgart city centre with individual charger pins
//   02StationDetail — a charger detail sheet
//   03Filter        — the filter sheet
//
// The app enters "screenshot mode" via the -screenshotMode launch argument
// (also keys off FASTLANE_SNAPSHOT): it pins the map to Stuttgart Mitte at a
// tight zoom so single chargers show instead of clusters.
final class evchargeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "-onboardingDone", "YES",
            "-screenshotMode", "YES",
            "-dataSources", "goingElectric",  // single source so no filters are greyed out
        ]
        app.launch()

        // Dismiss the system location-permission alert if it appears.
        // Button index 1 = "Allow While Using App" — language-independent.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            let allow = alert.buttons.element(boundBy: 1)
            (allow.exists ? allow : alert.buttons.firstMatch).tap()
        }

        // Wait for chargers to load (pins appear), then screenshot the map.
        let pin = app.buttons.matching(identifier: "chargerPin").firstMatch
        _ = pin.waitForExistence(timeout: 25)
        sleep(2)
        snapshot("01Map")

        // 2) Filter sheet — open, screenshot, dismiss by dragging the grabber down.
        let filterButton = app.buttons["filterButton"]
        if filterButton.waitForExistence(timeout: 5) {
            filterButton.tap()
            sleep(1)
            snapshot("03Filter")
            // Dismiss: drag the sheet's nav bar down off-screen.
            let navBar = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.13))
            let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
            navBar.press(forDuration: 0.2, thenDragTo: bottom)
            sleep(2)
        }

        // 3) Station detail — prefer the HPC Ladepark (300 kW EnBW, rich detail);
        // fall back to any pin. Charger names are proper nouns, not localized.
        // Opens at the .large detent in screenshot mode (full sheet). Captured
        // last, so no dismissal needed.
        let named = app.buttons.matching(
            NSPredicate(format: "identifier == 'chargerPin' AND label CONTAINS[c] 'Ladepark'")
        ).firstMatch
        let detailPin = named.exists ? named : pin
        if detailPin.exists {
            detailPin.tap()
            sleep(2)
            snapshot("02StationDetail")
        }
    }
}
