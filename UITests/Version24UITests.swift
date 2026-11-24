import XCTest

/// 2.4: exercises are dragged into order and Remove is a word that asks first; a Tailored step
/// carries a speed or power and is Effort or Easy; the plan page has each figure beside its name.
final class Version24UITests: XCTestCase {
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
    private func type(_ text: String, into id: String) {
        let field = app.textFields[id]
        // A row below the screen edge is not there yet: scroll down to it in small steps.
        for _ in 0..<10 where !field.waitForExistence(timeout: 1) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)))
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5), id)
        app.reveal(field)
        field.tap()
        // Return puts the keyboard away, so the list under it can be scrolled and dragged.
        field.typeText(text + "\n")
    }
    private func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 8,
                         file: StaticString = #filePath, line: UInt = #line) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        if XCTWaiter.wait(for: [found], timeout: timeout) != .completed {
            XCTFail("expected \"\(label)\", saw \"\(e.exists ? e.label : "nothing")\"", file: file, line: line)
        }
    }

    func testExercisesAreDraggedIntoOrderAndRemovedByWord() {
        XCTAssertTrue(app.buttons["add-workout"].waitForExistence(timeout: 10))
        app.buttons["add-workout"].tap()
        app.buttons["new-checklist"].tap()
        type("Knee", into: "editor-name")

        // Add exercise still works with the grips showing; one exercise has no Order block yet.
        app.reveal(app.buttons["editor-add-exercise"])
        app.buttons["editor-add-exercise"].tap()
        type("Bridge", into: "exercise-name-1")
        XCTAssertFalse(any("exercise-order-1").exists)
        app.reveal(app.buttons["editor-add-exercise"])
        app.buttons["editor-add-exercise"].tap()
        type("Squat", into: "exercise-name-2")

        // Two exercises: the Order block lists them, and the old menu is gone.
        let first = any("exercise-order-1")
        // The Order block sits above the exercises: scroll back up until it is clear of the title bar.
        for _ in 0..<10 where !(first.exists && first.isHittable && first.frame.minY > 130) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)))
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "Bridge")
        XCTAssertEqual(any("exercise-order-2").label, "Squat")
        XCTAssertFalse(app.buttons["Exercise 1 options"].exists)
        picture("2.4 order")

        // Drag Squat by its grip above Bridge. GitHub's hosted simulator never takes the long-press drag.
        if !(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? "").hasPrefix("/Users/runner") {
            let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
            XCTAssertGreaterThanOrEqual(handles.count, 2)
            for _ in 0..<3 where any("exercise-order-1").label != "Squat" {
                // Drop it in the upper part of the first line: a drop above the block itself is not taken.
                let from = handles.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let to = handles.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                from.press(forDuration: 1.0, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.6)
            }
            XCTAssertEqual(any("exercise-order-1").label, "Squat")
            XCTAssertEqual(app.textFields["exercise-name-1"].value as? String, "Squat")
        }

        // Remove is a word and asks first.
        let remove = app.buttons["exercise-remove-2"]
        app.reveal(remove)
        remove.tap()
        let confirm = app.buttons["exercise-remove-confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        picture("2.4 remove")
        confirm.tap()
        XCTAssertFalse(app.textFields["exercise-name-2"].waitForExistence(timeout: 2))

        app.buttons["editor-save"].tap()
        let card = app.buttons["workout-Knee"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("1 exercise"), card.label)
    }

    func testAStepCarriesSpeedOrPowerAndEffortOrEasy() {
        XCTAssertTrue(app.buttons["add-workout"].waitForExistence(timeout: 10))
        app.buttons["add-workout"].tap()
        app.buttons["new-tailored"].tap()
        type("Hill", into: "editor-name")

        // The example: Jog is Effort, Walk is Easy; a tap switches.
        let effort = app.buttons["step-effort-1"]
        app.reveal(effort)
        XCTAssertEqual(effort.label, "Effort")
        XCTAssertEqual(app.buttons["step-effort-2"].label, "Easy")
        effort.tap()
        waitFor(effort, label: "Easy")
        effort.tap()
        waitFor(effort, label: "Effort")
        type("8 km/h", into: "step-target-1")
        picture("2.4 steps")

        // Add step carries on: an eleventh step, Jog again, with the ninth step's Effort.
        let add = app.buttons["editor-add-step"]
        app.reveal(add)
        add.tap()
        let eleventh = app.textFields["step-name-11"]
        XCTAssertTrue(eleventh.waitForExistence(timeout: 5))
        XCTAssertEqual(eleventh.value as? String, "Jog")
        picture("2.4 steps bottom")
        app.buttons["editor-save"].tap()

        // The plan page: the figure right beside its name, with the speed.
        let card = app.buttons["workout-Hill"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("11 steps"), card.label)
        card.tap()
        let line = any("plan-line-1")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("8 km/h"), line.label)
        picture("2.4 plan")
        app.buttons["plan-done"].tap()

        // Running: the speed under the step's name; the walk after it is an Easy step.
        app.buttons["start-Hill"].tap()
        let phase = app.staticTexts["run-phase"]
        waitFor(phase, label: "JOG", timeout: 14)
        waitFor(any("run-target"), label: "8 km/h")
        picture("2.4 run effort")
        app.buttons["run-skip"].tap()
        waitFor(phase, label: "WALK")
        XCTAssertFalse(any("run-target").exists)
        picture("2.4 run easy")
        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }
}
