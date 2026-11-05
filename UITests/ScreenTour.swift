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

    /// Back one page: on a machine (no back arrow since 1.9) the bottom button ("Back to machines" before a set, then "Exercise done"), else the back arrow.
    func goBack() {
        let done = app.buttons["machine-done-pill"]
        if done.exists && done.isHittable { done.tap(); return }
        let arrow = app.navigationBars.buttons["BackButton"]
        if arrow.exists && arrow.isHittable { arrow.tap(); return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
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
        goBack()
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
        goBack()
        app.buttons["gym-finish"].tap()
        XCTAssertTrue(app.staticTexts["gym-summary-sets"].waitForExistence(timeout: 5))
        snap("14 Summary")
        app.buttons["gym-summary-done"].tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-edit-machine"].tap()
        XCTAssertTrue(app.textFields["machine-name"].waitForExistence(timeout: 5))
        snap("15 Machine form")
        app.buttons["machine-cancel"].tap()
        goBack()
        goBack()
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
        app.buttons["machine-Push-ups"].tap()
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        snap("20 Reps only")
        goBack()
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        app.buttons["backup-keep-copy"].tap()
        XCTAssertTrue(app.buttons["backup-copy-0"].waitForExistence(timeout: 5))
        snap("21 Backups")
    }

    /// 1.7: Repeat last visit on the gym screen, and automatic backup.
    func testNewIn17Tour() {
        app.launchArguments += ["-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["gym-repeat"].waitForExistence(timeout: 5))
        snap("22 Repeat last visit")
        app.buttons["gym-repeat"].tap()
        XCTAssertTrue(app.buttons["plan-row-1"].waitForExistence(timeout: 5))
        snap("23 Repeated plan")
        goBack()
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        XCTAssertTrue(app.buttons["backup-auto-on"].waitForExistence(timeout: 5))
        snap("24 Backups automatic")
    }

    /// 1.8: the backup reminder, the Undo bar, the week picture and Check my data.
    func testNewIn18Tour() {
        app.launchArguments += ["-gymdemo", "-backupdue"]
        app.launch()
        XCTAssertTrue(app.staticTexts["backup-reminder"].waitForExistence(timeout: 10))
        app.buttons["workout-Intervals"].press(forDuration: 1.2)
        app.buttons["Delete"].firstMatch.tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["undo-bar"].waitForExistence(timeout: 5))
        snap("25 Reminder and Undo")
        app.buttons["open-history"].tap()
        XCTAssertTrue(app.segmentedControls["history-week-switch"].waitForExistence(timeout: 5))
        snap("26 Week picture")
        app.buttons["open-settings"].tap()
        app.buttons["settings-health"].tap()
        XCTAssertTrue(app.staticTexts["health-ok"].waitForExistence(timeout: 5))
        snap("27 Check my data")
    }

    /// 1.9: new icons and gear, bold gym title, Exercise done, history with notes, bottom buttons, statistics.
    func testNewIn19Tour() {
        app.launchArguments += ["-gymdemo"]
        app.launch()
        XCTAssertTrue(app.buttons["open-gym"].waitForExistence(timeout: 10))
        snap("28 Train")
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.staticTexts["gym-intro"].waitForExistence(timeout: 5))
        snap("29 Gym")
        app.buttons["machine-Lat pulldown"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        app.swipeUp()
        snap("30 Machine history")
        app.buttons["gym-edit-machine"].tap()
        XCTAssertTrue(app.buttons["machine-save"].waitForExistence(timeout: 5))
        snap("31 Form buttons at the bottom")
        app.buttons["machine-cancel"].tap()
        app.buttons["machine-done-pill"].tap()
        app.buttons["open-history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["stats-period"].waitForExistence(timeout: 5))
        snap("32 Statistics")
        app.swipeUp()
        snap("33 Badges")
    }

    /// 1.9.1: Exercise done above the tab bar, and the colourful gym visit.
    func testNewIn191Tour() {
        app.launchArguments += ["-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Lat pulldown"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        snap("34 Exercise done visible")
        app.buttons["machine-done-pill"].tap()
        app.buttons["open-history"].tap()
        let row = app.buttons["history-row-1"]
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.staticTexts["visit-sets"].waitForExistence(timeout: 5))
        snap("35 Gym visit")
    }

    /// 1.9.3: the plan sheet with drag handles.
    func testNewIn193Tour() {
        app.launchArguments += ["-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Leg press"].tap()
        app.buttons["plan-machine-Chest press"].tap()
        app.buttons["plan-machine-Treadmill"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-order-3"].waitForExistence(timeout: 5))
        snap("36 Plan with handles")
    }

    /// 1.10: plan templates and the Muscle groups page.
    func testNewIn110Tour() {
        app.launchArguments += ["-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Leg press"].tap()
        app.buttons["plan-machine-Chest press"].tap()
        app.buttons["plan-save-template"].tap()
        let field = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        snap("37 Save as template")
        field.typeText("Leg day")
        app.alerts.firstMatch.buttons["Save"].firstMatch.tap()
        app.buttons["plan-cancel"].tap()
        app.buttons["gym-plan"].tap()
        XCTAssertTrue(app.buttons["plan-template-Leg day"].waitForExistence(timeout: 5))
        app.buttons["plan-template-Leg day"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-order-2"].waitForExistence(timeout: 5))
        snap("38 Use a template")
        app.buttons["plan-cancel"].tap()
        goBack()
        app.buttons["open-settings"].tap()
        app.descendants(matching: .any)["open-muscle-groups"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["muscle-add"].firstMatch.waitForExistence(timeout: 5))
        snap("39 Muscle groups")
        app.descendants(matching: .any)["muscle-row-Legs"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["muscle-name"].firstMatch.waitForExistence(timeout: 5))
        snap("40 Edit a muscle group")
    }

    /// 1.11: muscle stripes, find a machine, warm-up, superset, machine settings, rest times.
    func testNewIn111Tour() {
        app.launchArguments += ["-gymdemo", "-gymextras"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.textFields["gym-search"].waitForExistence(timeout: 5))
        app.swipeUp()
        snap("41 Stripes and search")
        app.swipeDown()
        app.swipeDown()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-warmup"].tap()
        snap("42 Superset and warm-up")
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.navigationBars["Lat pulldown"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gym-superset-next"].firstMatch.waitForExistence(timeout: 5))
        snap("43 Superset rest")
        app.buttons["gym-edit-machine"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["machine-name"].firstMatch.waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["machine-partner"].firstMatch.waitForExistence(timeout: 5))
        snap("44 Machine: heavy, rest, superset")
        app.buttons["machine-cancel"].tap()
        goBack()
        goBack()
        app.buttons["open-settings"].tap()
        app.descendants(matching: .any)["open-rest-times"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["rest-heavy"].firstMatch.waitForExistence(timeout: 5))
        snap("45 Rest times")
    }

    /// 1.11 in History: muscle balance, records wall, notes search, a visit with a warm-up, fixing a set, sharing.
    func testNewIn111HistoryTour() {
        app.launchArguments += ["-gymdemo", "-gymextras"]
        app.launch()
        let any = { (id: String) in self.app.descendants(matching: .any)[id].firstMatch }
        // A warm-up first, so the visit shows one.
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-warmup"].tap()
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        app.buttons["gym-set-done"].tap()
        goBack()
        app.buttons["gym-finish"].tap()
        app.buttons["gym-summary-done"].firstMatch.tap()
        goBack()
        app.buttons["open-history"].tap()
        XCTAssertTrue(any("stats-muscle-balance").waitForExistence(timeout: 10))
        any("stats-muscle-balance").swipeUp(velocity: .slow)
        snap("46 Muscle balance")
        app.buttons["open-records"].tap()
        XCTAssertTrue(any("records-row-1").waitForExistence(timeout: 5))
        snap("47 Records wall")
        goBack()
        app.buttons["open-notes-search"].tap()
        let field = app.textFields["notes-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("heavy")
        XCTAssertTrue(any("notes-hit-1").waitForExistence(timeout: 5))
        snap("48 Search my notes")
        goBack()
        app.swipeDown()
        app.swipeDown()
        app.swipeDown()
        app.buttons["history-row-1"].tap()
        XCTAssertTrue(app.buttons["visit-share"].waitForExistence(timeout: 10))
        snap("49 Visit with warm-up")
        app.buttons["visit-set-1-1"].tap()
        XCTAssertTrue(any("visit-set-warmup").waitForExistence(timeout: 5))
        snap("50 Change a set")
        app.buttons["visit-set-cancel"].tap()
        app.buttons["visit-share"].tap()
        Thread.sleep(forTimeInterval: 2)
        snap("51 Share a visit")
    }

    /// 1.13: the action tiles, the small Busy pill, Session done with photos, the visit's photos.
    func testNewIn113Tour() {
        app.launchArguments = ["-uitest", "-gymdemo", "-fakephoto"]
        app.launch()
        let any = { (id: String) in self.app.descendants(matching: .any)[id].firstMatch }
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        app.buttons["busy-Leg press"].tap()
        snap("52 Gym tiles and Busy")
        app.buttons["busy-Leg press"].tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 3))
        app.buttons["machine-done-pill"].tap()
        app.buttons["gym-finish"].tap()
        XCTAssertTrue(any("session-photo-add").waitForExistence(timeout: 5))
        any("session-photo-add").tap()
        any("session-photo-add").tap()
        snap("53 Session done with photos")
        app.buttons["gym-summary-done"].firstMatch.tap()
        XCTAssertTrue(any("gym-session-done").waitForExistence(timeout: 5))
        snap("54 Session done line")
        let row = app.buttons["gym-visit-1"]
        while !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(any("session-photo-1").waitForExistence(timeout: 5))
        snap("55 Visit with photos")
    }

    func testNewIn117Tour() {
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        let any = { (id: String) in self.app.descendants(matching: .any)[id].firstMatch }
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["gym-plan"].waitForExistence(timeout: 5))
        snap("56 Small action tiles")
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
        snap("57 Session going")
    }

    func testNewIn118Tour() {
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        let any = { (id: String) in self.app.descendants(matching: .any)[id].firstMatch }
        app.buttons["open-gym"].tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        let finish = app.buttons["gym-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        app.swipeUp()
        snap("59 Finish with minutes")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(any("home-session-going").waitForExistence(timeout: 5))
        snap("58 Train with Session going")
    }
}
