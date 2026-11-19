import XCTest

/// 2.0 stretching (written, not run in the stretch lane): the chooser shows body areas and drag handles,
/// a tick is remembered after reopening, and the timer shows the big figure and Skip moves on.
/// It reaches the chooser from a finished gym visit through "Stretch now" (the gym lane's sheet).
final class Version20StretchUITests: XCTestCase {
    private func openChooser(_ app: XCUIApplication) {
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["gym-rest-skip"].tap()
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        app.buttons["gym-session-end"].tap()
        // 2.0: the End box offers "Stretch now".
        let box = app.alerts.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        box.buttons["Stretch now"].firstMatch.tap()
        XCTAssertTrue(app.buttons["stretch-choose-start"].waitForExistence(timeout: 5))
    }

    func testChooserShowsAreasAndDragHandleAndRemembersATick() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        openChooser(app)
        XCTAssertTrue(app.descendants(matching: .any)["stretch-drag-1"].firstMatch.waitForExistence(timeout: 5))
        let cobra = app.buttons["stretch-add-cobra"]
        for _ in 0..<8 where !(cobra.exists && cobra.isHittable) { app.swipeUp() }
        cobra.tap()
        XCTAssertEqual(cobra.value as? String, "chosen")
        XCTAssertTrue(app.descendants(matching: .any)["stretch-area-back"].firstMatch.exists)
        app.buttons["stretch-choose-close"].tap()
        // Open it again: the tick is still there.
        app.terminate(); app.launch()
        openChooser(app)
        for _ in 0..<8 where !(cobra.exists && cobra.isHittable) { app.swipeUp() }
        XCTAssertEqual(cobra.value as? String, "chosen")
    }

    func testTimerShowsTheFigureAndSkipMovesOn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        openChooser(app)
        app.buttons["stretch-choose-start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["stretch-figure"].firstMatch.waitForExistence(timeout: 5))
        let name = app.staticTexts["stretch-timer-name"]
        let first = name.label
        app.buttons["stretch-skip"].tap()
        expectation(for: NSPredicate(format: "label != %@", first), evaluatedWith: name)
        waitForExpectations(timeout: 5)
    }
}
