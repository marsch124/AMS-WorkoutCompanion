import XCTest

/// 2.3: a Tailored intervals workout, from New to its first step.
final class Version23UITests: XCTestCase {
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
    private func waitFor(_ e: XCUIElement, label: String, timeout: TimeInterval = 8,
                         file: StaticString = #filePath, line: UInt = #line) {
        let found = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: e)
        if XCTWaiter.wait(for: [found], timeout: timeout) != .completed {
            XCTFail("expected \"\(label)\", saw \"\(e.exists ? e.label : "nothing")\"", file: file, line: line)
        }
    }

    func testTailoredIntervalsFromNewToFirstStep() {
        XCTAssertTrue(app.buttons["add-workout"].waitForExistence(timeout: 10))
        app.buttons["add-workout"].tap()
        app.buttons["new-tailored"].tap()

        // The editor starts with the example: ten steps, 18:00.
        let first = any("step-name-1")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.value as? String, "Jog")
        picture("2.3 editor")
        let tenth = any("step-name-10")
        app.reveal(tenth)
        XCTAssertTrue(tenth.exists)
        let total = any("editor-steps-total")
        app.reveal(total)
        XCTAssertTrue(total.label.contains("18:00"), "total reads \(total.label)")
        picture("2.3 editor bottom")

        let name = app.textFields["editor-name"]
        if !name.isHittable { for _ in 0..<6 where !name.isHittable { app.swipeDown() } }
        name.tap()
        name.typeText("Pyramid")
        app.buttons["editor-save"].tap()

        let card = app.buttons["workout-Pyramid"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("10 steps"), "card reads \(card.label)")
        picture("2.3 workouts")
        card.tap()
        XCTAssertTrue(app.buttons["plan-done"].waitForExistence(timeout: 5))
        picture("2.3 plan")
        app.buttons["plan-done"].tap()
        app.buttons["start-Pyramid"].tap()

        let phase = app.staticTexts["run-phase"]
        waitFor(phase, label: "GET READY", timeout: 5)
        waitFor(phase, label: "JOG", timeout: 12)
        waitFor(any("run-next"), label: "Next: Walk 1:00")
        picture("2.3 run")

        app.buttons["run-skip"].tap()
        waitFor(phase, label: "WALK")

        app.buttons["run-close"].tap()
        app.buttons["run-end-confirm"].firstMatch.tap()
        XCTAssertTrue(app.buttons["workout-Pyramid"].waitForExistence(timeout: 5))
    }
}
