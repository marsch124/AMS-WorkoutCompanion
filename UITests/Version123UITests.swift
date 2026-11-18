import XCTest

/// 1.23: the session clock starts at the first machine opened, not when the gym screen opens.
final class Version123UITests: XCTestCase {
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

    func testTheSessionStartsAtTheFirstMachine() {
        XCTAssertFalse(any("gym-session-going").exists, "no session just from opening the gym")
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
    }
}
