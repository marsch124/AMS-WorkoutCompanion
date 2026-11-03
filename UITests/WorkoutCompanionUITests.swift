import XCTest

/// Every control is found by its accessibility identifier, never by its words.
/// The app starts with -uitest: a fresh, empty folder (the three starters) and no sound.
final class WorkoutCompanionUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    /// Waits for an element's label, since the screen animates between phases.
    func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 8,
                 file: StaticString = #filePath, line: UInt = #line) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        if XCTWaiter.wait(for: [found], timeout: timeout) != .completed {
            XCTFail("expected \"\(label)\", saw \"\(e.exists ? e.label : "nothing")\"", file: file, line: line)
        }
    }

    func testTheThreeStartersAreThere() {
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["workout-Intervals"].exists)
        XCTAssertTrue(app.buttons["workout-Doctor's exercises"].exists)
    }

    func testPushUpsDoneStartsTheRestAndSkipGoesToSetTwo() {
        app.buttons["workout-Push-ups"].tap()
        let set = app.descendants(matching: .any)["run-set"]
        waitFor(set, label: "Set 1 of 5")

        app.buttons["run-done"].tap()
        waitFor(app.staticTexts["run-phase"], label: "REST")
        // "Skip rest", so it cannot be read as skipping the whole workout.
        waitFor(app.buttons["run-skip"], label: "Skip rest")

        app.buttons["run-skip"].tap()
        waitFor(set, label: "Set 2 of 5")
    }

    func testIntervalsMoveOnByThemselvesAndPause() {
        app.buttons["workout-Intervals"].tap()
        // The 5-second get ready runs out on its own (a slow simulator may already be past it).
        let phase = app.staticTexts["run-phase"]
        waitFor(phase, label: "WORK", timeout: 20)
        app.buttons["run-pause"].tap()
        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].firstMatch.tap()
        XCTAssertTrue(app.buttons["workout-Intervals"].waitForExistence(timeout: 5))
    }

    func testMakeAnExerciseListAndTickItOff() {
        app.buttons["add-workout"].tap()
        app.buttons["new-checklist"].tap()

        let name = app.textFields["editor-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Knee")

        app.buttons["editor-add-exercise"].tap()
        let exercise = app.textFields["exercise-name-1"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        exercise.typeText("Bridge")
        app.buttons["editor-save"].tap()

        let card = app.buttons["workout-Knee"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let check = app.buttons["check-1"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        check.tap()
        XCTAssertTrue(app.descendants(matching: .any)["run-finished"].waitForExistence(timeout: 5))
    }

    func testEditChangesTheSets() {
        app.buttons["edit-Push-ups"].tap()
        let sets = app.steppers["editor-sets"]
        XCTAssertTrue(sets.waitForExistence(timeout: 5))
        sets.buttons.element(boundBy: 1).tap() // the + half
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout-Push-ups"].label.contains("6 × 20"))
    }

    func testSettingsShowsTheVersionAndWhatsNew() {
        app.buttons["open-settings"].tap()
        let version = app.staticTexts["settings-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertTrue(version.label.hasPrefix("1.3 ("), version.label)
        app.buttons["settings-new"].tap()
        XCTAssertTrue(app.staticTexts["whatsnew-1.3"].waitForExistence(timeout: 5))
    }

    func testANewWorkoutCanBeCancelled() {
        app.buttons["add-workout"].tap()
        app.buttons["new-reps"].tap()
        let cancel = app.buttons["editor-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["workout-"].exists)
    }

    func testTheNewWorkoutSheetCanBeCancelled() {
        app.buttons["add-workout"].tap()
        let cancel = app.buttons["new-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 5))
    }

    func testSaveWithoutANameSaysWhatIsMissing() {
        app.buttons["add-workout"].tap()
        app.buttons["new-reps"].tap()
        let save = app.buttons["editor-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["editor-name-needed"].waitForExistence(timeout: 3))
    }

    func testAtTheGymANewMachineTwoSetsAndFinish() {
        app.buttons["open-gym"].tap()
        app.buttons["gym-new-machine"].tap()
        let name = app.textFields["machine-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.buttons["machine-save"].tap()
        XCTAssertTrue(app.staticTexts["machine-name-needed"].waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Chest press")
        app.textFields["machine-setting"].tap()
        app.textFields["machine-setting"].typeText("Seat 4")
        app.buttons["machine-save"].tap()

        // Straight on to the machine, with a new machine's 20 kg × 10.
        XCTAssertTrue(app.staticTexts["gym-setting"].waitForExistence(timeout: 5))
        waitFor(app.staticTexts["gym-next-set"], label: "Set 1")
        app.buttons["gym-weight-plus"].tap()
        app.buttons["gym-weight-plus"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.staticTexts["gym-rest"].waitForExistence(timeout: 3))
        waitFor(app.buttons["gym-set-1"], label: "Set 1, 25 kg × 10")

        app.buttons["gym-rest-skip"].tap()
        waitFor(app.staticTexts["gym-next-set"], label: "Set 2")
        app.buttons["gym-reps-minus"].tap()
        app.buttons["gym-set-done"].tap()
        waitFor(app.buttons["gym-set-2"], label: "Set 2, 25 kg × 9")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        waitFor(app.buttons["gym-finish"], label: "Finish this session")
        app.buttons["gym-finish"].tap()
        waitFor(app.staticTexts["gym-summary-sets"], label: "2")
        waitFor(app.staticTexts["gym-summary-machines"], label: "1")
        app.buttons["gym-summary-done"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
    }

    func testABusyMachineMovesToComeBackToAndClearsWhenOpened() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        let busy = app.buttons["busy-Leg press"]
        XCTAssertTrue(busy.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["gym-come-back"].exists)

        // Busy, then free again with a second tap.
        busy.tap()
        XCTAssertTrue(app.staticTexts["gym-come-back"].waitForExistence(timeout: 3))
        waitFor(busy, label: "Leg press is busy")
        busy.tap()
        waitFor(busy, label: "Mark Leg press busy")
        XCTAssertFalse(app.staticTexts["gym-come-back"].exists)

        // Busy again; opening the machine when it is free takes the mark away.
        busy.tap()
        XCTAssertTrue(app.staticTexts["gym-come-back"].waitForExistence(timeout: 3))
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.staticTexts["gym-next-set"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(app.buttons["busy-Leg press"], label: "Mark Leg press busy")
        XCTAssertFalse(app.staticTexts["gym-come-back"].exists)
    }

    // MARK: 1.4

    func launchGymDemo() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
    }

    func testAPlanLeadsFromMachineToMachine() {
        launchGymDemo()
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Leg press"].tap()
        app.buttons["plan-machine-Chest press"].tap()
        app.buttons["plan-save"].tap()
        waitFor(app.buttons["plan-row-1"], label: "1, Leg press, up next")
        waitFor(app.buttons["plan-row-2"], label: "2, Chest press")

        app.buttons["plan-row-1"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gym-machine-done"].exists)
        app.buttons["gym-set-done"].tap()
        waitFor(app.buttons["gym-rest-skip"], label: "Skip rest")
        app.buttons["gym-rest-skip"].tap()
        // Done with this machine goes straight on to the next planned one.
        waitFor(app.buttons["gym-machine-done"], label: "Done with this machine, next: Chest press")
        app.buttons["gym-machine-done"].tap()
        waitFor(app.staticTexts["gym-setting"], label: "Seat 4, handles 2")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(app.buttons["plan-row-1"], label: "1, Leg press, done")
        waitFor(app.buttons["gym-finish"], label: "Finish this session")
    }

    func testASecondGymHasItsOwnMachines() {
        launchGymDemo()
        waitFor(app.buttons["gym-place-menu"], label: "Gym: My gym")
        app.buttons["gym-place-menu"].tap()
        app.buttons["gym-place-new"].tap()
        let name = app.textFields["gym-place-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Hotel gym")
        app.buttons["gym-place-save"].tap()
        waitFor(app.buttons["gym-place-menu"], label: "Gym: Hotel gym")
        XCTAssertFalse(app.buttons["machine-Chest press"].exists)

        app.buttons["gym-place-menu"].tap()
        app.buttons["gym-place-My gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 3))
    }

    func testFinishTakesAHeadingAndHistoryShowsEverything() {
        launchGymDemo()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["gym-finish"].tap()
        let title = app.textFields["gym-summary-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Chest day")
        app.buttons["gym-summary-done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // A Sets & reps workout ended early is kept too.
        app.buttons["workout-Push-ups"].tap()
        app.buttons["run-done"].tap()
        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].tap()

        app.buttons["open-history"].tap()
        let first = app.buttons["history-row-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.hasPrefix("Push-ups"), first.label)
        XCTAssertTrue(app.buttons["history-row-2"].label.hasPrefix("Chest day"), app.buttons["history-row-2"].label)
        XCTAssertTrue(app.staticTexts["history-week-sessions"].exists)
        app.buttons["history-filter-gym"].tap()
        XCTAssertTrue(app.buttons["history-row-1"].label.hasPrefix("Chest day"))
        XCTAssertFalse(app.buttons["history-row-2"].exists && app.buttons["history-row-2"].label.hasPrefix("Push-ups"))
    }
}
