import XCTest

/// Not a test: walks the main screens and attaches one picture of each, for checking a release
/// day and night. Skipped unless asked for:
///   xcrun simctl ui <device> appearance dark      (or light)
///   TEST_RUNNER_SCREEN_TOUR=1 xcodebuild test … -only-testing:AMSWorkoutCompanionUITests/ScreenTour
/// The pictures are attachments in the result bundle (xcresulttool export attachments).
final class ScreenTour: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREEN_TOUR"] == "1", "Runs only when asked for")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
    }

    /// Starts over with the three starters, so each picture begins from the Workouts screen.
    func fresh() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 10))
    }

    /// Lets sheets and rings finish moving, then takes the picture.
    func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 10) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        XCTAssertEqual(XCTWaiter.wait(for: [found], timeout: timeout), .completed, "expected \(label)")
    }

    func testTour() {
        fresh()
        snap("01 Workouts")

        app.buttons["add-workout"].tap()
        XCTAssertTrue(app.buttons["new-reps"].waitForExistence(timeout: 5))
        snap("02 New workout")

        fresh()
        app.buttons["edit-Push-ups"].tap()
        XCTAssertTrue(app.steppers["editor-sets"].waitForExistence(timeout: 5))
        snap("03 Push-ups editor")

        fresh()
        app.buttons["workout-Push-ups"].tap()
        waitFor(app.descendants(matching: .any)["run-set"], label: "Set 1 of 5")
        snap("04 Push-ups set")
        app.buttons["run-done"].tap()
        waitFor(app.staticTexts["run-phase"], label: "REST")
        snap("05 Rest")

        fresh()
        app.buttons["workout-Intervals"].tap()
        waitFor(app.staticTexts["run-phase"], label: "WORK", timeout: 20)
        snap("06 Interval round")

        fresh()
        app.buttons["edit-Doctor's exercises"].tap()
        app.buttons["editor-add-exercise"].tap()
        let name = app.textFields["exercise-name-1"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Bridge")
        app.textFields["exercise-amount-1"].tap()
        app.textFields["exercise-amount-1"].typeText("3 × 10")
        app.textFields["exercise-note-1"].tap()
        app.textFields["exercise-note-1"].typeText("Lift the hips slowly, hold 2 seconds at the top")
        app.buttons["editor-save"].tap()
        app.buttons["workout-Doctor's exercises"].tap()
        XCTAssertTrue(app.buttons["check-1"].waitForExistence(timeout: 5))
        snap("07 Doctor's exercises")

        fresh()
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-version"].waitForExistence(timeout: 5))
        snap("08 Settings")
        app.buttons["settings-new"].tap()
        XCTAssertTrue(app.staticTexts["whatsnew-1.2"].waitForExistence(timeout: 5))
        snap("09 What's new")
    }

    /// The gym log, with made-up machines and visits (-gymdemo).
    func testGymTour() {
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["edit-Push-ups"].tap()
        XCTAssertTrue(app.buttons["editor-save"].waitForExistence(timeout: 5))
        snap("10 Save button")
        app.buttons["editor-cancel"].tap()

        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        snap("11 Gym")
        app.buttons["busy-Lat pulldown"].tap()
        XCTAssertTrue(app.staticTexts["gym-come-back"].waitForExistence(timeout: 3))
        snap("11b Busy")
        app.buttons["machine-Chest press"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gym-suggestion"].waitForExistence(timeout: 5))
        snap("12 Machine")
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.staticTexts["gym-rest"].waitForExistence(timeout: 3))
        snap("13 Rest")
        app.buttons["gym-rest-skip"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["gym-finish"].tap()
        XCTAssertTrue(app.staticTexts["gym-summary-sets"].waitForExistence(timeout: 5))
        snap("14 Summary")
        app.buttons["gym-summary-done"].tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-edit-machine"].tap()
        XCTAssertTrue(app.textFields["machine-name"].waitForExistence(timeout: 5))
        snap("15 Machine form")
    }
}
