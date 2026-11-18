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
        for _ in 0..<8 where !(stretch.exists && stretch.isHittable) { app.swipeUp() }
        stretch.tap()

        // Choose: keep the first two of six.
        let count = app.staticTexts["stretch-choose-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "6 of 6 chosen")
        for n in 3...6 { app.buttons["stretch-choose-\(n)"].tap() }
        XCTAssertEqual(count.label, "2 of 6 chosen")
        shot(app, "134-choose")
        app.buttons["stretch-choose-start"].tap()
        XCTAssertTrue(app.staticTexts["stretch-timer-progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["stretch-timer-progress"].label.hasPrefix("Stretch 1 of 2"))

        // Hold more than half the first side, then Save: that stretch counts.
        let phase = app.staticTexts["stretch-timer-phase"]
        expectation(for: NSPredicate(format: "label BEGINSWITH 'HOLD'"), evaluatedWith: phase)
        waitForExpectations(timeout: 12)
        sleep(17)
        shot(app, "134-save")
        app.buttons["stretch-timer-save"].tap()
        let done = app.descendants(matching: .any)["stretch-timer-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '1 of 2 stretches'")).firstMatch.exists)
        app.buttons["stretch-timer-close-done"].tap()
        XCTAssertTrue(app.buttons["gym-summary-done"].waitForExistence(timeout: 5))
        app.buttons["gym-summary-done"].tap()

        // History: the stretch row and the gym visit with its warm-up set.
        app.buttons["open-history"].tap()
        let stretchRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-row-' AND label CONTAINS '1 of 2 chosen stretches'")).firstMatch
        XCTAssertTrue(stretchRow.waitForExistence(timeout: 5), "the stretch shows in History")
        shot(app, "134-history")
        let visit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-row-' AND label BEGINSWITH 'At the gym'")).firstMatch
        XCTAssertTrue(visit.exists)
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
