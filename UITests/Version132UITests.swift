import XCTest

/// 1.32 (his ask): the guided stretch timer with voice cues, from Stretch now on the Well done page.
final class Version132UITests: XCTestCase {
    func testStretchNowRunsTheGuidedTimer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        app.buttons["gym-session-end"].tap()
        app.confirmEnd()
        let stretch = app.buttons["gym-stretch"]
        XCTAssertTrue(app.buttons["gym-summary-done"].waitForExistence(timeout: 5))
        for _ in 0..<8 where !(stretch.exists && stretch.isHittable) { app.swipeUp() }
        stretch.tap()

        let phase = app.staticTexts["stretch-timer-phase"]
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.label, "GET READY")
        XCTAssertEqual(app.staticTexts["stretch-timer-name"].label, "Chest in a doorway")
        XCTAssertTrue(app.staticTexts["stretch-timer-progress"].label.hasPrefix("Stretch 1 of 6"))
        // After the 8 s to get ready: hold, first side.
        let hold = NSPredicate(format: "label BEGINSWITH 'HOLD'")
        expectation(for: hold, evaluatedWith: phase)
        waitForExpectations(timeout: 12)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "132-timer"; a.lifetime = .keepAlways; add(a)

        app.buttons["stretch-timer-pause"].tap()
        let seconds = app.staticTexts["stretch-timer-seconds"].label
        sleep(2)
        XCTAssertEqual(app.staticTexts["stretch-timer-seconds"].label, seconds, "paused stands still")
        app.buttons["stretch-timer-skip"].tap()
        XCTAssertTrue(app.staticTexts["stretch-timer-progress"].label.hasPrefix("Stretch 2 of 6"))
        app.buttons["stretch-timer-close"].tap()
        XCTAssertTrue(app.buttons["gym-summary-done"].waitForExistence(timeout: 5))
    }
}
