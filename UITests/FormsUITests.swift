import XCTest

/// Version 1.9 forms: Cancel/Save at the bottom, the Exercise done pill, the muscle group and the richer history.
final class FormsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    func waitHittable(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: e)
        if XCTWaiter.wait(for: [ready], timeout: 5) != .completed { XCTFail("not tappable: \(e)", file: file, line: line) }
    }

    func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 8,
                 file: StaticString = #filePath, line: UInt = #line) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        if XCTWaiter.wait(for: [found], timeout: timeout) != .completed {
            XCTFail("expected \"\(label)\", saw \"\(e.exists ? e.label : "nothing")\"", file: file, line: line)
        }
    }

    func launchGymDemo() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
    }

    func testTheGymIntroSaysWhichMachineNext() {
        launchGymDemo()
        let intro = app.staticTexts["gym-intro"]
        XCTAssertTrue(intro.waitForExistence(timeout: 5))
        XCTAssertTrue(intro.label.contains("Tap the machine you'll use next"), intro.label)
    }

    func testExerciseDonePillGoesBackToTheGymAndThereIsNoBackButton() {
        launchGymDemo()
        app.buttons["machine-Chest press"].tap()
        let pill = app.buttons["machine-done-pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["At the gym"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Back"].exists)
        pill.tap()
        XCTAssertTrue(app.buttons["gym-new-machine"].waitForExistence(timeout: 5))
    }

    func testMachineFormButtonsAreLowAndTheMuscleSaves() {
        launchGymDemo()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-edit-machine"].tap()
        let save = app.buttons["machine-save"], cancel = app.buttons["machine-cancel"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let half = app.windows.firstMatch.frame.height / 2
        XCTAssertGreaterThan(save.frame.midY, half)
        XCTAssertGreaterThan(cancel.frame.midY, half)

        let muscle = app.buttons["machine-muscle"]
        for _ in 0..<4 where !muscle.isHittable { app.swipeUp() }
        waitHittable(muscle)
        muscle.tap()
        app.buttons["Chest"].firstMatch.tap()
        save.tap()

        XCTAssertTrue(app.buttons["gym-edit-machine"].waitForExistence(timeout: 5))
        app.buttons["gym-edit-machine"].tap()
        let again = app.buttons["machine-muscle"]
        for _ in 0..<4 where !again.isHittable { app.swipeUp() }
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertTrue(again.label.contains("Chest") || ("\(again.value ?? "")").contains("Chest"), "\(again.label) / \(again.value ?? "")")
        app.buttons["machine-cancel"].tap()
    }

    func testTheHistoryShowsTheNoteOfAVisit() {
        launchGymDemo()
        app.buttons["machine-Lat pulldown"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        app.buttons["gym-rest-skip"].tap()
        app.buttons["gym-next-time"].tap()
        let note = app.textFields["next-time-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        note.typeText("Smooth and strong")
        app.buttons["next-time-save"].tap()
        XCTAssertTrue(app.buttons["gym-next-time"].waitForExistence(timeout: 3))
        let shown = app.staticTexts.matching(identifier: "history-visit-note")
        for _ in 0..<6 where shown.count == 0 { app.swipeUp() }
        XCTAssertGreaterThan(shown.count, 0)
        let mine = shown.containing(NSPredicate(format: "label CONTAINS 'Smooth and strong'"))
        for _ in 0..<6 where mine.count == 0 { app.swipeUp() }
        XCTAssertGreaterThan(mine.count, 0)
    }
}
