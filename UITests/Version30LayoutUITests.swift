import XCTest

/// 3.0 (his pick, "Side list"): on a wide screen (iPad, the Mac) a side list replaces the tab bar.
final class Version30LayoutUITests: XCTestCase {
    func testSideListOnAWideScreen() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .phone, "the side list is for the iPad and the Mac")
        continueAfterFailure = false
        // He holds the iPad on its side.
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-gymextras"]
        app.launch()
        for id in ["side-workouts", "side-gym", "side-history", "side-settings"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 8), id)
        }
        XCTAssertTrue(app.buttons["side-workouts"].isSelected)
        XCTAssertFalse(app.buttons["open-train"].exists, "no phone tab bar on a wide screen")
        XCTAssertFalse(app.buttons["open-gym"].exists, "the gym has its own row, no card")
        shot("30-side-workouts")

        app.buttons["side-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        shot("30-side-gym")

        app.buttons["side-history"].tap()
        XCTAssertTrue(app.buttons["side-history"].isSelected)
        sleep(1)
        shot("30-side-history")

        app.buttons["side-settings"].tap()
        XCTAssertTrue(app.buttons["settings-how"].waitForExistence(timeout: 5)
                      || app.staticTexts["Help"].waitForExistence(timeout: 2))
        shot("30-side-settings")

        // Settings → iCloud: the status with its dot (in a test there is no iCloud, so it says it is off).
        app.buttons["settings-icloud"].tap()
        let status = app.descendants(matching: .any)["icloud-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "iCloud is off")
        XCTAssertEqual(app.descendants(matching: .any)["sync-status"].label, "iCloud is off")
        shot("30-icloud")
    }

    /// The iPhone keeps its tab bar; Settings has the new iCloud row and page.
    func testICloudPageOnThePhone() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the phone look")
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.buttons["open-settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["side-gym"].exists, "no side list on the phone")
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["settings-icloud"].waitForExistence(timeout: 5))
        app.buttons["settings-icloud"].tap()
        let status = app.descendants(matching: .any)["icloud-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "iCloud is off")
        XCTAssertFalse(app.buttons["icloud-sync-now"].exists, "nothing to sync while iCloud is off")
        shot("30-icloud-phone")
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
