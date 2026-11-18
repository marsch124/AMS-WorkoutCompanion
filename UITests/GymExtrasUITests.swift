import XCTest

/// 1.11 on the gym and machine screens: warm-ups, supersets, rest times, find a machine,
/// Save as template from last visit. Made-up data (-gymdemo -gymextras), found by identifier.
final class GymExtrasUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-gymextras"]
        app.launch()
    }

    private func openGym() {
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    /// 1.11.3: an earlier visit's date has the year. Since 1.30 the list is folded behind a toggle
    /// that names the gym (his ask); closed when the screen opens.
    func testEarlierVisitsNameTheGymAndTheDateHasTheYear() {
        openGym()
        let toggle = app.buttons["gym-earlier-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue((toggle.value as? String ?? "").hasPrefix("Hidden."), "\(String(describing: toggle.value))")
        XCTAssertTrue((toggle.value as? String ?? "").contains(" at "), "names the gym: \(String(describing: toggle.value))")
        XCTAssertFalse(app.buttons["gym-visit-1"].exists, "closed at first")
        app.showEarlierVisits()
        XCTAssertTrue(app.buttons["gym-visit-1"].isHittable, "the opened list scrolls into view (1.32)")
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "130-earlier-open"; a.lifetime = .keepAlways; add(a)
        let row = app.buttons["gym-visit-1"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }   // it sits far below the machines
        row.tap()
        let date = any("visit-date")
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let year = String(Calendar.current.component(.year, from: Date()))
        XCTAssertTrue(date.label.contains(year), date.label)
    }

    /// Up the weight far past the best (Leg press: 55 kg), then Set done.
    private func heavySet() {
        let plus = app.buttons["gym-weight-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        for _ in 0..<8 { plus.tap() }
        app.buttons["gym-set-done"].tap()
    }

    func testAWarmUpIsNeverANewBest() {
        openGym()
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-warmup"].tap()
        heavySet()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gym-set-1"].label.hasPrefix("Warm-up"), app.buttons["gym-set-1"].label)
        // "New best" shows over the next set, after the rest.
        app.buttons["gym-rest-skip"].tap()
        XCTAssertTrue(app.buttons["gym-warmup"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("gym-new-best").exists, "a warm-up must not be a New best")
        XCTAssertFalse(app.buttons["gym-warmup"].isSelected, "warm-up switches itself off after one set")

        heavySet()
        app.buttons["gym-rest-skip"].tap()
        XCTAssertTrue(any("gym-new-best").waitForExistence(timeout: 5), "a working set this heavy is a New best")
    }

    func testASupersetGoesStraightToThePartnerThenRests() {
        openGym()
        app.buttons["machine-Chest press"].tap()
        XCTAssertTrue(any("gym-superset").waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        // Straight to Lat pulldown, no rest.
        XCTAssertTrue(app.navigationBars["Lat pulldown"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("gym-rest").exists)
        app.buttons["gym-set-done"].tap()
        // Round done: rest, with the partner as the way on.
        XCTAssertTrue(any("gym-rest").waitForExistence(timeout: 5))
        app.buttons["gym-superset-next"].tap()
        XCTAssertTrue(app.navigationBars["Chest press"].waitForExistence(timeout: 5))
    }

    func testRestTimesAreUsedByMachinesWithoutTheirOwn() {
        app.buttons["open-settings"].tap()
        app.buttons["open-rest-times"].tap()
        let plus = app.steppers["rest-light"].buttons.element(boundBy: 1)
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()   // 1:30 → 1:45
        app.buttons["rest-save"].tap()
        app.buttons["open-train"].tap()
        openGym()
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        let rest = app.staticTexts["gym-rest"]
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        XCTAssertTrue(rest.label.hasPrefix("1:4"), "rest should start at 1:45, shows \(rest.label)")
    }

    func testFindAMachineInALongList() {
        openGym()
        let search = app.textFields["gym-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "10 machines: the search field shows")
        search.tap()
        search.typeText("curl")
        XCTAssertTrue(app.buttons["machine-Leg curl"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["machine-Biceps curl"].exists)
        XCTAssertFalse(app.buttons["machine-Leg press"].exists, "Leg press does not match")
    }

    /// Since 1.30 (his ask) Save as template is part of finishing: on the Well done summary.
    func testSaveTheSessionAsATemplateWhenFinishing() {
        openGym()
        XCTAssertFalse(app.buttons["gym-repeat-template"].exists, "no longer on the gym screen's head")
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        for _ in 0..<10 where !app.buttons["gym-finish"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["gym-finish"].waitForExistence(timeout: 5))
        app.buttons["gym-finish"].tap()
        app.confirmEnd()
        let save = app.buttons["gym-summary-template"]
        for _ in 0..<6 where !save.isHittable { app.swipeUp() }
        save.tap()
        let field = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Tuesday")
        app.alerts.firstMatch.buttons["gym-summary-template-save"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Saved as template · Tuesday"].waitForExistence(timeout: 5))
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "130-summary-template"; a.lifetime = .keepAlways; add(a)
        app.buttons["gym-summary-done"].firstMatch.tap()
        app.buttons["gym-plan"].tap()
        XCTAssertTrue(app.buttons["plan-template-Tuesday"].waitForExistence(timeout: 5), "the template is not listed")
    }

    /// 1.30 (his ask): Discard session in the End box throws the session away, after asking once more.
    func testDiscardSessionThrowsItAway() {
        openGym()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        let end = app.buttons["gym-session-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        let discard = app.alerts.firstMatch.buttons["Discard session"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "130-end-box"; a.lifetime = .keepAlways; add(a)
        discard.tap()
        let sure = app.alerts["Discard this session?"]
        XCTAssertTrue(sure.waitForExistence(timeout: 5))
        sure.buttons["Discard session"].firstMatch.tap()
        XCTAssertFalse(any("gym-session-going").waitForExistence(timeout: 2), "the session is gone")
        XCTAssertFalse(any("gym-session-done").exists, "nothing counted as done")
    }

    /// 1.30 (his ask): Discard on the Session done page throws the finished session away.
    func testDiscardOnTheSessionDonePage() {
        openGym()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        let end = app.buttons["gym-session-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        app.confirmEnd()
        let discard = app.buttons["gym-summary-discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "130-summary-discard"; a.lifetime = .keepAlways; add(a)
        discard.tap()
        app.alerts.firstMatch.buttons["Discard session"].firstMatch.tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("gym-session-done").exists, "nothing counted as done")
    }
}
