import XCTest

/// 1.25: rest has -15 s beside +15 s; the green session line has an End button.
final class Version125UITests: XCTestCase {
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

    func testRestHasMinusFifteenAndTheSessionLineHasEnd() {
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-rest-less"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gym-rest-more"].exists)
        do { let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "125-rest"; a.lifetime = .keepAlways; add(a) }
        app.buttons["gym-rest-less"].tap()
        XCTAssertTrue(app.buttons["gym-rest-skip"].waitForExistence(timeout: 5))
        app.buttons["gym-rest-skip"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        do { let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "125-gym"; a.lifetime = .keepAlways; add(a) }
        app.buttons["gym-session-end"].tap()
        XCTAssertTrue(app.buttons["gym-feel-good"].waitForExistence(timeout: 5))
        app.buttons["gym-summary-done"].tap()
        XCTAssertFalse(any("gym-session-going").waitForExistence(timeout: 2))
    }
}
