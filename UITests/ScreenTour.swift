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
        XCTAssertTrue(app.staticTexts["whatsnew-1.5"].waitForExistence(timeout: 5))
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
        app.buttons["busy-Lat pulldown"].tap()
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Leg press"].tap()
        app.buttons["plan-machine-Chest press"].tap()
        app.buttons["plan-machine-Treadmill"].tap()
        snap("11c Plan sheet")
        app.buttons["plan-save"].tap()
        XCTAssertTrue(app.buttons["plan-row-1"].waitForExistence(timeout: 3))
        snap("11d Plan")
        app.buttons["plan-row-3"].tap()
        XCTAssertTrue(app.buttons["gym-minutes-plus"].waitForExistence(timeout: 5))
        snap("11e Treadmill")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["machine-Chest press"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gym-suggestion"].waitForExistence(timeout: 5))
        snap("12 Machine")
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.staticTexts["gym-rest"].waitForExistence(timeout: 3))
        snap("13 Rest")
        app.buttons["gym-rest-skip"].tap()
        snap("13b Done with this machine")
        app.buttons["gym-next-time"].tap()
        XCTAssertTrue(app.textFields["next-time-note"].waitForExistence(timeout: 3))
        snap("13c Next time")
        app.buttons["next-time-cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["gym-finish"].tap()
        XCTAssertTrue(app.staticTexts["gym-summary-sets"].waitForExistence(timeout: 5))
        snap("14 Summary")
        app.buttons["gym-summary-done"].tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-edit-machine"].tap()
        XCTAssertTrue(app.textFields["machine-name"].waitForExistence(timeout: 5))
        snap("15 Machine form")
        app.buttons["machine-cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["open-history"].tap()
        XCTAssertTrue(app.buttons["history-row-1"].waitForExistence(timeout: 5))
        snap("16 History")
    }

    /// 1.6: the larger At the gym title, the icon picker, a reps-only exercise and Backups.
    func testNewIn16Tour() {
        app.launch()
        XCTAssertTrue(app.buttons["open-gym"].waitForExistence(timeout: 10))
        snap("17 Train")
        app.buttons["edit-Push-ups"].tap()
        app.buttons["editor-icon"].tap()
        XCTAssertTrue(app.buttons["icon-run"].waitForExistence(timeout: 5))
        snap("18 Icon picker")
        app.buttons["icon-picker-cancel"].tap()
        app.buttons["editor-cancel"].firstMatch.tap()
        app.buttons["open-gym"].tap()
        app.buttons["gym-new-machine"].tap()
        let name = app.textFields["machine-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Push-ups")
        app.segmentedControls["machine-logs"].buttons.element(boundBy: 2).tap()
        snap("19 New exercise")
        app.buttons["machine-save"].tap()
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        snap("20 Reps only")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        app.buttons["backup-keep-copy"].tap()
        XCTAssertTrue(app.buttons["backup-copy-0"].waitForExistence(timeout: 5))
        snap("21 Backups")
    }
}
