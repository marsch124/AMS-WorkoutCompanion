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

    /// Waits until an element can be tapped (a sheet or full-screen workout may still be closing).
    func waitHittable(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: e)
        if XCTWaiter.wait(for: [ready], timeout: 5) != .completed { XCTFail("not tappable: \(e)", file: file, line: line) }
    }

    /// Waits for an element's label, since the screen animates between phases.
    /// Back one page: on a machine (no back arrow since 1.9) the bottom button ("Back to machines" before a set, then "Exercise done"), else the back arrow.
    func goBack() {
        let done = app.buttons["machine-done-pill"]
        if done.exists && done.isHittable { done.tap(); return }
        let arrow = app.navigationBars.buttons["BackButton"]
        if arrow.exists && arrow.isHittable { arrow.tap(); return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
    }

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
        XCTAssertTrue(version.label.hasPrefix("1.19 ("), version.label)
        app.buttons["settings-new"].tap()
        XCTAssertTrue(app.staticTexts["whatsnew-1.19"].waitForExistence(timeout: 5))
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

        // Saving only defines the machine (since 1.16.2): back on the gym screen, its tile there.
        let tile = app.buttons["machine-Chest press"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gym-set-done"].exists, "saving a new machine must not open it")
        XCTAssertFalse(app.buttons["machine-done-pill"].exists)

        // Tap it to log: a new machine's 20 kg × 10.
        tile.tap()
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

        goBack()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        waitFor(app.buttons["gym-finish"], label: "Finish this session")
        app.buttons["gym-finish"].tap()
        waitFor(app.staticTexts["gym-summary-sets"], label: "2")
        waitFor(app.staticTexts["gym-summary-machines"], label: "1")
        app.buttons["gym-summary-done"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
    }

    /// 1.13: photos of a session — added on Session done, shown on the visit page, removed after asking.
    func testASessionKeepsItsPhotos() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo", "-fakephoto"]
        app.launch()
        let any = { (id: String) in self.app.descendants(matching: .any)[id].firstMatch }
        app.buttons["open-gym"].tap()
        app.buttons["machine-Chest press"].tap()
        waitFor(app.staticTexts["gym-next-set"], label: "Set 1")
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 3))
        goBack()
        app.buttons["gym-finish"].tap()

        let add = any("session-photo-add")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        add.tap()
        XCTAssertTrue(any("session-photo-2").waitForExistence(timeout: 5))
        app.buttons["gym-summary-done"].firstMatch.tap()

        // The finished session is the newest earlier visit; its page shows both photos.
        let row = app.buttons["gym-visit-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        while !row.isHittable { app.swipeUp() }
        row.tap()
        waitFor(any("session-photos"), label: any("session-photos").label)
        XCTAssertTrue(any("session-photo-2").waitForExistence(timeout: 5))
        XCTAssertEqual(any("session-photos").value as? String, "2 photos")
        // 1.14: the first session photo goes into the share picture.
        waitFor(app.buttons["visit-share"], label: "Share this visit")
        XCTAssertEqual(app.buttons["visit-share"].value as? String, "0 photos, session photo")

        any("session-photo-1").tap()
        app.buttons["session-photo-remove"].tap()
        app.buttons["session-photo-remove-confirm"].firstMatch.tap()
        XCTAssertTrue(any("session-photo-1").waitForExistence(timeout: 5))
        XCTAssertFalse(any("session-photo-2").exists)
        XCTAssertEqual(any("session-photos").value as? String, "1 photo")
    }

    /// 1.12: after Finish the button goes, the session joins Earlier visits, and a set starts a second session.
    func testFinishClosesTheSessionAndASecondOneCanStart() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'gym-visit-'"))
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        let before = rows.count

        func oneSet() {
            app.buttons["machine-Chest press"].tap()
            waitFor(app.staticTexts["gym-next-set"], label: "Set 1")
            app.buttons["gym-set-done"].tap()
            XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))  // 3 s was too short on GitHub's slower Mac (5 Nov)
            goBack()
            XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        }

        oneSet()
        XCTAssertTrue(app.buttons["gym-finish"].waitForExistence(timeout: 3))
        app.buttons["gym-finish"].tap()
        app.buttons["gym-summary-done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gym-finish"].exists, "Finish must go once the session is stored")
        XCTAssertTrue(app.descendants(matching: .any)["gym-session-done"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, before + 1, "the finished session is listed under Earlier visits")

        // A second session the same day: Finish is back, starting again at set 1.
        oneSet()
        XCTAssertTrue(app.buttons["gym-finish"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["gym-session-done"].firstMatch.exists)
        app.buttons["gym-finish"].tap()
        app.buttons["gym-summary-done"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["gym-session-done"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, before + 2)
    }

    /// 1.14: Undo Finish — the session goes on, Finish is back, and it is not listed as done.
    func testUndoFinishKeepsTheSessionOpen() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'gym-visit-'"))
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        let before = rows.count
        app.buttons["machine-Chest press"].tap()
        waitFor(app.staticTexts["gym-next-set"], label: "Set 1")
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 3))
        goBack()
        app.buttons["gym-finish"].tap()
        let undo = app.buttons["gym-summary-undo"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.buttons["gym-finish"].waitForExistence(timeout: 5), "Finish is back after Undo")
        XCTAssertFalse(app.descendants(matching: .any)["gym-session-done"].firstMatch.exists)
        XCTAssertEqual(rows.count, before, "the session is not listed as an earlier visit")
    }

    /// 1.14: a session can be deleted from its page; Undo brings it back.
    func testDeleteASessionAndUndo() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-history"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-row-'"))
        let row = app.buttons["history-row-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let before = rows.count
        row.tap()
        let delete = app.buttons["visit-delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        while !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["visit-delete-confirm"].firstMatch.tap()
        XCTAssertTrue(app.buttons["undo-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, before - 1, "the session is gone from History")
        app.buttons["undo-button"].tap()
        let back = NSPredicate(format: "count == %d", before)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: back, evaluatedWith: rows)], timeout: 5), .completed, "Undo brings it back")
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
        goBack()
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
        // Changing a set done (crashed before 1.4: read while changing).
        app.buttons["gym-set-1"].tap()
        app.buttons["set-edit-save"].tap()
        // Done with this machine goes straight on to the next planned one.
        waitFor(app.buttons["gym-machine-done"], label: "Done with this machine, next: Chest press")
        // Green and on the same line as Set done (1.5).
        XCTAssertEqual(app.buttons["gym-machine-done"].frame.midY, app.buttons["gym-set-done"].frame.midY, accuracy: 2)
        app.buttons["gym-machine-done"].tap()
        waitFor(app.staticTexts["gym-setting"], label: "Seat 4, handles 2")

        goBack()
        waitFor(app.buttons["plan-row-1"], label: "1, Leg press, done")
        waitFor(app.buttons["gym-finish"], label: "Finish this session")
    }

    func testASecondGymHasItsOwnMachines() {
        launchGymDemo()
        waitFor(app.buttons["gym-place-menu"], label: "Gym: My gym")
        app.buttons["gym-place-menu"].tap()
        app.buttons["gym-place-new"].tap()
        // Alert text fields do not take an identifier; find it inside the alert.
        let name = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Hotel gym")
        app.alerts.firstMatch.buttons["Save"].firstMatch.tap()
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
        goBack()
        app.buttons["gym-finish"].tap()
        let title = app.textFields["gym-summary-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Chest day")
        app.buttons["gym-summary-done"].tap()
        goBack()

        // A Sets & reps workout ended early is kept too.
        app.buttons["workout-Push-ups"].tap()
        waitFor(app.descendants(matching: .any)["run-set"], label: "Set 1 of 5")
        app.buttons["run-done"].tap()
        waitFor(app.staticTexts["run-phase"], label: "REST")
        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].firstMatch.tap()
        // Back on Train once the workout has closed.
        waitHittable(app.buttons["workout-Push-ups"])

        app.buttons["open-history"].tap()
        let first = app.buttons["history-row-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.hasPrefix("Push-ups"), first.label)
        XCTAssertTrue(app.buttons["history-row-2"].label.hasPrefix("Chest day"), app.buttons["history-row-2"].label)
        XCTAssertTrue(app.staticTexts["history-week-sessions"].exists)
        // A session opens (1.4 on the iPhone showed a yellow warning triangle instead).
        let row = app.buttons["history-row-2"]
        row.tap()
        XCTAssertTrue(app.buttons["visit-edit"].waitForExistence(timeout: 5))
        goBack()
        let gymChip = app.buttons["history-filter-gym"]
        // Since 1.9 the statistics push the list down: scroll back up to the chips.
        for _ in 0..<4 where !gymChip.isHittable { app.swipeDown() }
        waitHittable(gymChip)
        gymChip.tap()
        XCTAssertTrue(app.buttons["history-row-1"].label.hasPrefix("Chest day"))
        XCTAssertFalse(app.buttons["history-row-2"].exists && app.buttons["history-row-2"].label.hasPrefix("Push-ups"))
    }

    func testATimeMachineAndAPlanForNextTime() {
        launchGymDemo()
        // Last time's note shows on the machine.
        app.buttons["machine-Lat pulldown"].tap()
        XCTAssertTrue(app.staticTexts["gym-last-note"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["gym-suggestion"].label.contains("Your plan from last time"))
        goBack()

        app.buttons["machine-Treadmill"].tap()
        XCTAssertTrue(app.staticTexts["gym-last"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["gym-last"].label.contains("25 min · level 8 · incline 2 %"), app.staticTexts["gym-last"].label)
        XCTAssertTrue(app.buttons["gym-minutes-plus"].exists)
        XCTAssertTrue(app.buttons["gym-incline-plus"].exists)
        app.buttons["gym-minutes-plus"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["gym-set-1"].label.contains("26 min"), app.buttons["gym-set-1"].label)

        app.buttons["gym-next-time"].tap()
        let note = app.textFields["next-time-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        note.typeText("Felt easy")
        app.buttons["next-time-save"].tap()
        XCTAssertTrue(app.buttons["gym-next-time"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["gym-next-time"].label.contains("Felt easy"), app.buttons["gym-next-time"].label)
    }

    // MARK: 1.5

    func testTheHomeHasTabsTheHeadingAndTwoColumns() {
        XCTAssertTrue(app.navigationBars["Workout Companion"].waitForExistence(timeout: 5))
        let push = app.buttons["workout-Push-ups"], intervals = app.buttons["workout-Intervals"]
        XCTAssertTrue(push.exists && intervals.exists)
        // Two columns: Push-ups and Intervals side by side.
        XCTAssertEqual(push.frame.midY, intervals.frame.midY, accuracy: 2)
        XCTAssertLessThan(push.frame.maxX, intervals.frame.minX)
        XCTAssertTrue(app.buttons["add-workout-tile"].exists)

        app.buttons["open-history"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["workout-Push-ups"].isHittable)
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-version"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["settings-done"].exists)
        app.buttons["open-train"].tap()
        XCTAssertTrue(app.buttons["workout-Push-ups"].isHittable)
    }

    func testAMachineHasItsOwnRestAndWeightStep() {
        launchGymDemo()
        // The date is no longer at the top; an earlier day is in the gym menu.
        XCTAssertFalse(app.datePickers["gym-date"].exists)
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-edit-machine"].tap()
        let step = app.segmentedControls["machine-step"]
        // Since 1.6 the form is longer (an Icon row): scroll down to the machine's settings.
        XCTAssertTrue(app.textFields["machine-name"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !step.isHittable { app.swipeUp() }
        XCTAssertTrue(step.waitForExistence(timeout: 5))
        step.buttons.element(boundBy: 2).tap()
        let rest = app.steppers["machine-rest"]
        for _ in 0..<4 { rest.buttons.element(boundBy: 1).tap() }
        app.buttons["machine-save"].tap()

        let kg = app.textFields["gym-weight"]
        XCTAssertTrue(kg.waitForExistence(timeout: 5))
        XCTAssertEqual(kg.value as? String, "55")
        app.buttons["gym-weight-plus"].tap()
        XCTAssertEqual(kg.value as? String, "60")
        app.buttons["gym-set-done"].tap()
        let left = app.staticTexts["gym-rest"]
        XCTAssertTrue(left.waitForExistence(timeout: 3))
        XCTAssertTrue(left.label.hasPrefix("2:"), left.label)
    }

    // MARK: 1.6

    func testAnExerciseWithoutAMachineLogsRepsOnly() {
        app.buttons["open-gym"].tap()
        app.buttons["gym-new-machine"].tap()
        let name = app.textFields["machine-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Push-ups")
        app.segmentedControls["machine-logs"].buttons.element(boundBy: 2).tap()
        // Reps only: no weight step, no "More weight at".
        XCTAssertFalse(app.segmentedControls["machine-step"].exists)
        XCTAssertFalse(app.steppers["machine-top-reps"].exists)
        XCTAssertTrue(app.steppers["machine-rest"].exists)
        app.buttons["machine-save"].tap()
        app.buttons["machine-Push-ups"].tap()

        // No weight on the exercise: reps only, starting at 10.
        waitFor(app.staticTexts["gym-next-set"], label: "Set 1")
        XCTAssertFalse(app.textFields["gym-weight"].exists)
        app.buttons["gym-reps-plus"].tap()
        app.buttons["gym-set-done"].tap()
        waitFor(app.buttons["gym-set-1"], label: "Set 1, 11 reps")

        app.buttons["gym-rest-skip"].tap()
        goBack()
        XCTAssertTrue(app.buttons["machine-Push-ups"].waitForExistence(timeout: 5))
        app.buttons["gym-finish"].tap()
        waitFor(app.staticTexts["gym-summary-sets"], label: "1")
        XCTAssertFalse(app.staticTexts["gym-summary-total"].exists)
    }

    func testABackupCopyCanBeRestored() {
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        XCTAssertTrue(app.buttons["backup-now"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["backup-restore-file"].exists)
        XCTAssertFalse(app.buttons["backup-copy-0"].exists)
        app.buttons["backup-keep-copy"].tap()
        XCTAssertTrue(app.buttons["backup-copy-0"].waitForExistence(timeout: 5))

        app.buttons["backup-copy-0"].tap()
        let restore = app.alerts.firstMatch.buttons["backup-restore-confirm"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts.containing(NSPredicate(format: "label CONTAINS '3 workouts'")).firstMatch.exists)
        restore.tap()
        let message = app.staticTexts["backup-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.hasPrefix("Restored: 3 workouts"), message.label)

        app.buttons["open-train"].tap()
        XCTAssertTrue(app.buttons["workout-Push-ups"].waitForExistence(timeout: 5))
    }

    func testBackUpNowOpensTheShareSheet() {
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        app.buttons["backup-now"].tap()
        // The iPhone's own share sheet, with Save to Files.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 8)
                      || app.collectionViews.cells.firstMatch.waitForExistence(timeout: 2))
    }

    func testASecondGymCanBePlannedToo() {
        launchGymDemo()
        app.buttons["gym-place-menu"].tap()
        app.buttons["gym-place-new"].tap()
        let gym = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(gym.waitForExistence(timeout: 3))
        gym.typeText("Hotel gym")
        app.alerts.firstMatch.buttons["Save"].firstMatch.tap()
        waitFor(app.buttons["gym-place-menu"], label: "Gym: Hotel gym")
        for n in ["Rower", "Squats", "Dips"] {
            app.buttons["gym-new-machine"].tap()
            let name = app.textFields["machine-name"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            name.tap()
            name.typeText(n)
            app.buttons["machine-save"].tap()
            XCTAssertTrue(app.buttons["machine-\(n)"].waitForExistence(timeout: 5))
        }
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Squats"].tap()
        app.buttons["plan-machine-Rower"].tap()
        app.buttons["plan-save"].tap()
        waitFor(app.buttons["plan-row-1"], label: "1, Squats, up next")
        waitFor(app.buttons["plan-row-2"], label: "2, Rower")
    }

    func testAWorkoutGetsTheIconYouChoose() {
        app.buttons["edit-Push-ups"].tap()
        let icon = app.buttons["editor-icon"]
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        icon.tap()
        let run = app.buttons["icon-car"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        app.buttons["icon-picker-save"].tap()
        XCTAssertEqual(app.buttons["editor-icon"].value as? String, "car")
        app.buttons["editor-save"].tap()
        app.buttons["edit-Push-ups"].tap()
        XCTAssertTrue(app.buttons["editor-icon"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["editor-icon"].value as? String, "car")
    }

    func testTheGymTileIconCanBeChanged() {
        let tile = app.buttons["open-gym"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.2)
        let change = app.buttons["gym-change-icon"].firstMatch
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()
        XCTAssertTrue(app.buttons["icon-car"].waitForExistence(timeout: 5))
        app.buttons["icon-car"].tap()
        app.buttons["icon-picker-save"].tap()
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
    }

    // MARK: 1.7

    func testRepeatLastVisitPlansTheSameMachines() {
        launchGymDemo()
        let repeatButton = app.buttons["gym-repeat"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 5))
        repeatButton.tap()
        XCTAssertTrue(app.buttons["plan-row-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plan-row-1"].label.hasSuffix("up next"), app.buttons["plan-row-1"].label)
        XCTAssertFalse(app.buttons["gym-repeat"].exists)
    }

    func testAutomaticBackupAsksForAFolder() {
        app.buttons["open-settings"].tap()
        app.buttons["settings-backups"].tap()
        let on = app.buttons["backup-auto-on"]
        XCTAssertTrue(on.waitForExistence(timeout: 5))
        on.tap()
        // The iPhone's own folder picker opens.
        XCTAssertTrue(app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 20)  // 8 s ran out on GitHub (5 Nov)
                      || app.buttons["Cancel"].waitForExistence(timeout: 2))
    }

    // MARK: 1.8

    func testDeletingAWorkoutCanBeUndone() {
        let push = app.buttons["workout-Push-ups"]
        XCTAssertTrue(push.waitForExistence(timeout: 5))
        push.press(forDuration: 1.2)
        app.buttons["Delete"].firstMatch.tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["undo-bar"].waitForExistence(timeout: 5))
        XCTAssertFalse(push.exists)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(push.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["undo-bar"].exists)
    }

    func testRemovingASetCanBeUndone() {
        launchGymDemo()
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        app.buttons["gym-set-1"].tap()
        app.buttons["set-edit-remove"].tap()
        XCTAssertTrue(app.staticTexts["undo-bar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gym-set-1"].exists)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5))
    }

    func testTheBackupReminderOpensBackupsAndLaterHidesIt() {
        app.terminate()
        app.launchArguments = ["-uitest", "-backupdue"]
        app.launch()
        XCTAssertTrue(app.staticTexts["backup-reminder"].waitForExistence(timeout: 5))
        app.buttons["backup-reminder-open"].tap()
        XCTAssertTrue(app.buttons["backup-now"].waitForExistence(timeout: 5))
        goBack()
        app.buttons["backup-reminder-later"].tap()
        XCTAssertFalse(app.staticTexts["backup-reminder"].waitForExistence(timeout: 2))
    }

    func testTheWeekPictureSwitchesAndTheDataCheckIsAllGood() {
        launchGymDemo()
        goBack()
        app.buttons["open-history"].tap()
        let sw = app.segmentedControls["history-week-switch"]
        XCTAssertTrue(sw.waitForExistence(timeout: 5))
        sw.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(sw.buttons.element(boundBy: 1).isSelected)
        app.buttons["open-settings"].tap()
        app.buttons["settings-health"].tap()
        XCTAssertTrue(app.staticTexts["health-ok"].waitForExistence(timeout: 5))
    }
}
