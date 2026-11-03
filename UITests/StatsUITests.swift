import XCTest

/// 1.9: History's statistics, found by identifier, with made-up data (-gymdemo).
final class StatsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testStatisticsShowAndThePeriodSwitches() {
        app.buttons["open-history"].tap()
        let sw = app.segmentedControls["stats-period"]
        XCTAssertTrue(sw.waitForExistence(timeout: 10))
        XCTAssertTrue(any("stats-week").exists)
        sw.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(sw.buttons.element(boundBy: 1).isSelected)
        XCTAssertTrue(any("stats-month").waitForExistence(timeout: 5))
        XCTAssertFalse(any("stats-week").exists)
        sw.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(any("stats-week").waitForExistence(timeout: 5))

        for id in ["stats-muscle", "stats-warmup", "stats-streak", "stats-badges"] {
            XCTAssertTrue(any(id).waitForExistence(timeout: 5), id)
        }
        // Since 1.11 Muscle balance sits above the badges: scroll down to them first.
        let first = any("stats-badge-first")
        for _ in 0..<4 where !first.exists { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(first.waitForExistence(timeout: 5))
    }
}
