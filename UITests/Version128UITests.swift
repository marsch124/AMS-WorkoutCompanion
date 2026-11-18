import XCTest

/// 1.28: the first tab is called Workouts; a workout's panel shows the plan only, the pen edits,
/// the play button starts.
final class Version128UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func picture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testThePanelShowsThePlanThePenEditsAndPlayStarts() {
        let panel = app.buttons["workout-Push-ups"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["open-train"].label, "Workouts")
        // The dashed New workout tile is gone; the round + is at the bottom right, under the panels.
        XCTAssertFalse(app.buttons["add-workout-tile"].exists)
        XCTAssertGreaterThan(app.buttons["add-workout"].frame.minY, panel.frame.maxY)
        XCTAssertGreaterThan(app.buttons["add-workout"].frame.midX, app.windows.firstMatch.frame.midX)
        picture("128-workouts")

        // The panel: the plan, to read only — nothing starts.
        panel.tap()
        XCTAssertTrue(any("plan-line-1").waitForExistence(timeout: 5))
        XCTAssertEqual(any("plan-line-1").label, "Sets, 5")
        XCTAssertTrue(any("plan-line-3").exists)
        XCTAssertFalse(any("run-set").exists, "the plan does not start the workout")
        XCTAssertFalse(app.buttons["editor-save"].exists, "the plan cannot be edited")
        picture("128-plan")
        app.buttons["plan-done"].tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))

        // An exercise list shows its exercises.
        app.buttons["workout-Doctor's exercises"].tap()
        XCTAssertTrue(app.buttons["plan-done"].waitForExistence(timeout: 5))
        picture("128-plan-list")
        app.buttons["plan-done"].tap()

        // The pen: the editor.
        app.buttons["edit-Push-ups"].tap()
        XCTAssertTrue(app.buttons["editor-save"].waitForExistence(timeout: 5))
        app.buttons["editor-cancel"].firstMatch.tap()

        // The play button: the workout starts.
        XCTAssertTrue(app.buttons["start-Push-ups"].waitForExistence(timeout: 5))
        app.buttons["start-Push-ups"].tap()
        XCTAssertTrue(any("run-set").waitForExistence(timeout: 5))
    }
}
