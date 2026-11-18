import XCTest

/// 1.31 (his asks): change the weight during the rest, and a small session clock on the machine page.
final class Version131UITests: XCTestCase {
    func testWeightDuringRestAndTheSessionClock() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        let clock = app.descendants(matching: .any)["machine-session-clock"].firstMatch
        XCTAssertTrue(clock.waitForExistence(timeout: 5), "the clock shows at the top left")
        XCTAssertLessThan(clock.frame.midX, app.frame.width / 2)
        app.buttons["gym-set-done"].tap()
        let weight = app.textFields["gym-rest-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "the weight shows during the rest")
        let before = weight.value as? String
        app.buttons["gym-rest-weight-plus"].tap()
        XCTAssertNotEqual(weight.value as? String, before)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "131-rest"; a.lifetime = .keepAlways; add(a)
        app.buttons["gym-rest-skip"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
    }
}
