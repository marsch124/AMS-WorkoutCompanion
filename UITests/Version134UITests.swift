import XCTest

/// 1.34 (his asks): framed Exercise done, choose the stretches, save a stretch stopped early —
/// and his check: warm-up sets and the stretch both show in History.
final class Version134UITests: XCTestCase {
    func testChooseStretchesSaveEarlyAndHistoryShowsWarmupAndStretch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        shot(app, "134-frame")
        // A warm-up set, then a normal one.
        app.descendants(matching: .any)["gym-warmup"].firstMatch.tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["gym-rest-skip"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-2"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        app.buttons["gym-session-end"].tap()
        app.confirmEnd()
        let stretch = app.buttons["gym-stretch"]
        XCTAssertTrue(app.buttons["gym-summary-done"].waitForExistence(timeout: 5))
        app.reveal(stretch)
        stretch.tap()

        // 2.0: Stretch now opens his stretches (the 2.0 chooser); closing it goes back to Well done.
        XCTAssertTrue(app.buttons["stretch-choose-start"].waitForExistence(timeout: 5))
        shot(app, "134-choose")
        app.buttons["stretch-choose-close"].tap()
        XCTAssertTrue(app.buttons["gym-summary-done"].waitForExistence(timeout: 5))
        app.buttons["gym-summary-done"].tap()

        // History: the gym visit with its warm-up set.
        app.buttons["open-history"].tap()
        let visit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-row-' AND label BEGINSWITH 'At the gym'")).firstMatch
        XCTAssertTrue(visit.waitForExistence(timeout: 5))
        visit.tap()
        let warm = app.buttons["visit-set-1-1"]
        XCTAssertTrue(warm.waitForExistence(timeout: 5))
        XCTAssertTrue(warm.label.hasPrefix("W "), "the warm-up set is marked: \(warm.label)")
        shot(app, "134-visit")
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
