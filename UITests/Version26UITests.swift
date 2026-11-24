import XCTest

/// 2.6: the Workouts page heading, an effort button on every Tailored step, the Settings sections.
final class Version26UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    private func picture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testWorkoutsHeadingEffortButtonAndSettingsSections() {
        XCTAssertTrue(app.buttons["add-workout"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Workouts"].exists)
        XCTAssertFalse(app.navigationBars["Workout Companion"].exists)

        // A new Tailored workout: each step shows its effort; tapping one lets me pick another.
        app.buttons["add-workout"].tap()
        app.buttons["new-tailored"].tap()
        let one = app.buttons["step-effort-1"], two = app.buttons["step-effort-2"]
        XCTAssertTrue(one.waitForExistence(timeout: 5))
        app.reveal(one)
        XCTAssertTrue(one.label.contains("Steady"), one.label)
        XCTAssertTrue(two.label.contains("Easy"), two.label)
        one.tap()
        app.buttons["Hard"].firstMatch.tap()
        XCTAssertTrue(one.label.contains("Hard"), one.label)
        picture("editor")
        app.buttons["editor-cancel"].tap()

        // Settings: the three sections and their rows.
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["settings-how"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-backups"].exists)
        XCTAssertTrue(app.buttons["settings-sounds"].exists)
        for header in ["Help", "Training", "Your data"] {
            let match = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", header)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 5), header)
        }
    }
}
