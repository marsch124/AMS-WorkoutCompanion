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
        app.buttons["End workout"].tap()
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
        XCTAssertTrue(version.label.hasPrefix("1.1 ("), version.label)
        app.buttons["settings-new"].tap()
        XCTAssertTrue(app.staticTexts["whatsnew-1.1"].waitForExistence(timeout: 5))
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
}
