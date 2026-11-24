import XCTest

/// 2.5: a Tailored step carries pace, power, weight and level — the ones chosen for the workout;
/// no Effort / Easy button; the plan page has each figure beside its name.
final class Version25UITests: XCTestCase {
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
        // Return puts the keyboard away, so the list under it can be scrolled.
        field.typeText(text + "\n")
    }
    private func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 8,
                         file: StaticString = #filePath, line: UInt = #line) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        if XCTWaiter.wait(for: [found], timeout: timeout) != .completed {
            XCTFail("expected \"\(label)\", saw \"\(e.exists ? e.label : "nothing")\"", file: file, line: line)
        }
    }

    func testAStepCarriesPacePowerWeightAndLevel() {
        XCTAssertTrue(app.buttons["add-workout"].waitForExistence(timeout: 10))
        app.buttons["add-workout"].tap()
        app.buttons["new-tailored"].tap()
        type("Hill", into: "editor-name")

        // Nothing chosen: no boxes, and no Effort / Easy button any more.
        let pace = app.buttons["measure-pace"]
        app.reveal(pace)
        XCTAssertFalse(app.buttons["step-effort-1"].exists)
        XCTAssertFalse(app.textFields["step-pace-1"].exists)
        XCTAssertFalse(app.textFields["step-target-1"].exists)

        // Choose Pace and Power: every step gets a box for each.
        pace.tap()
        app.buttons["measure-power"].tap()
        type("530", into: "step-pace-1")
        XCTAssertEqual(app.textFields["step-pace-1"].value as? String, "5:30")
        type("150", into: "step-power-1")
        type("7:00", into: "step-pace-2")
        XCTAssertFalse(app.textFields["step-weight-1"].exists)
        picture("2.5 steps")

        // All four: the boxes wrap onto a second row.
        app.reveal(app.buttons["measure-weight"])
        app.buttons["measure-weight"].tap()
        app.buttons["measure-level"].tap()
        type("22,5", into: "step-weight-1")
        type("8", into: "step-level-1")
        picture("2.5 steps all four")
        app.reveal(app.buttons["measure-weight"])
        app.buttons["measure-weight"].tap()
        app.buttons["measure-level"].tap()
        app.buttons["editor-save"].tap()

        // The plan page: the figure right beside its name, with the numbers the workout uses.
        let card = app.buttons["workout-Hill"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let line = any("plan-line-1")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("5:30 /km \u{B7} 150 W"), line.label)
        XCTAssertFalse(line.label.contains("kg"), line.label)
        picture("2.5 plan")
        app.buttons["plan-done"].tap()

        // Running: the numbers under the step's name; a walk runs in the workout's colour too.
        app.buttons["start-Hill"].tap()
        let phase = app.staticTexts["run-phase"]
        waitFor(phase, label: "JOG", timeout: 14)
        waitFor(any("run-target"), label: "5:30 /km \u{B7} 150 W")
        waitFor(any("run-next"), label: "Next: Walk 1:00 \u{B7} 7:00 /km")
        picture("2.5 run jog")
        app.buttons["run-skip"].tap()
        waitFor(phase, label: "WALK")
        waitFor(any("run-target"), label: "7:00 /km")
        picture("2.5 run walk")
        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }
}
