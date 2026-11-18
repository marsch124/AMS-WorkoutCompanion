import XCTest

/// 1.22: the gym screen shows a running session clock and a "Done this session" list.
final class Version122UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testClockAndDoneList() {
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
        XCTAssertTrue(any("gym-session-going").label.contains("0:0"), any("gym-session-going").label)
        XCTAssertFalse(any("gym-done-list").exists, "no list before the first set")

        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["gym-machine-done"].exists, "only one way on since 1.22")
        app.buttons["machine-done-pill"].tap()

        XCTAssertTrue(any("gym-done-list").waitForExistence(timeout: 5))
        let row = any("gym-done-Leg press")
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5), "the row opens the machine again")
    }
}
