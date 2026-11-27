import XCTest

/// 1.23: opening hours, Reminder and stretch, effort and pain on a machine, the Session done page,
/// and a session that never starts again by itself after Finish.
final class Version123ScreensUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func picture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openGym() {
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
    }

    func testOpeningHours() {
        openGym()
        XCTAssertFalse(any("gym-hours-line").exists, "no line before hours are given")
        app.buttons["gym-place-menu"].tap()
        app.buttons["gym-place-hours"].tap()
        let monday = app.switches["hours-day-1"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        picture("123-hours-a")
        monday.switches.firstMatch.exists ? monday.switches.firstMatch.tap() : monday.tap()
        picture("123-hours-b")
        app.buttons["hours-copy"].tap()
        picture("123-hours")
        app.buttons["hours-save"].tap()
        XCTAssertTrue(any("gym-hours-line").waitForExistence(timeout: 5))
        picture("123-gym-hours-line")
    }

    func testReminderAndStretch() {
        app.buttons["open-settings"].tap()
        let row = app.buttons["settings-gym-extras"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(any("extras-days-value").waitForExistence(timeout: 5))
        XCTAssertTrue(any("extras-days-value").label.contains("4 days"))
        picture("123-extras")
        app.buttons["extras-save"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testMachineExtrasAndSessionDone() {
        openGym()
        app.buttons["machine-Leg press"].tap()
        // Since 3.4 last time's set stands only in the Last time beside today box (the faint line is gone).
        XCTAssertTrue(any("gym-last-1").waitForExistence(timeout: 5), "the same set last time, in the box")
        XCTAssertFalse(any("gym-last-set").exists)
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["gym-effort-hard"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].label.contains("hard"), app.buttons["gym-set-1"].label)
        app.buttons["gym-rest-skip"].tap()
        let pain = app.buttons["gym-pain"]
        XCTAssertTrue(pain.waitForExistence(timeout: 5))
        pain.tap()
        XCTAssertEqual(pain.label, "Pain flagged")
        picture("123-machine")
        app.buttons["machine-done-pill"].tap()

        let finish = app.buttons["gym-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        app.confirmEnd()
        // 2.2: Stretch now and Save as template come first, right under Well done.
        let stretchNow = app.buttons["gym-stretch"]
        XCTAssertTrue(stretchNow.waitForExistence(timeout: 5))
        XCTAssertTrue(stretchNow.isHittable, "Stretch now shows without scrolling")
        let good = app.buttons["gym-feel-good"]
        app.reveal(good)
        good.tap()
        picture("123-session-done")
        app.reveal(any("gym-compare-sets"))
        picture("123-session-done-lower")
        app.buttons["gym-summary-done"].tap()

        // Finish ends the session for good: nothing starts again by itself.
        XCTAssertTrue(any("gym-session-done").waitForExistence(timeout: 5))
        sleep(2)
        XCTAssertFalse(any("gym-session-going").exists, "no new session by itself after Finish")
        picture("123-after-finish")
    }

    func testFinishWithNoSetDoesNotStartAgain() {
        openGym()
        XCTAssertFalse(any("gym-session-going").exists, "no session before the first machine")
        app.buttons["machine-Leg press"].tap()
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
        app.buttons["gym-finish"].tap()
        app.confirmEnd()
        sleep(2)
        XCTAssertFalse(any("gym-session-going").exists, "Finish ends it and it stays ended")
        XCTAssertFalse(app.buttons["gym-finish"].exists)
    }
}
