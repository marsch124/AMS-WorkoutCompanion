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
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
