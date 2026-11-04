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

    /// 1.11.3: the Earlier visits heading names the gym; an earlier visit's date has the year.
    func testEarlierVisitsNameTheGymAndTheDateHasTheYear() {
        openGym()
        let heading = any("gym-earlier-heading")
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(heading.label.hasPrefix("Earlier visits · "), heading.label)
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

    func testSaveLastVisitAsATemplate() {
        openGym()
        app.buttons["gym-repeat-template"].tap()
        let field = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Tuesday")
        app.alerts.firstMatch.buttons["gym-repeat-template-save"].firstMatch.tap()
        app.buttons["gym-plan"].tap()
        XCTAssertTrue(app.buttons["plan-template-Tuesday"].waitForExistence(timeout: 5), "the template is not listed")
    }
}
