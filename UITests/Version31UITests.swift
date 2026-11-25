import XCTest

/// 3.1: after Finish, a small "Open Triathlon" button — only when AMS Triathlon Training is installed.
/// The launch argument -triathloninstalled (debug builds) pretends it is; nothing is opened.
final class Version31UITests: XCTestCase {
    func testOpenTriathlonShowsAfterFinish() {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments = ["-uitest", "-gymdemo", "-triathloninstalled"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["gym-rest-skip"].tap()
        app.buttons["machine-done-pill"].tap()
        let finish = app.buttons["gym-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        app.confirmEnd()
        XCTAssertTrue(app.buttons["gym-open-triathlon"].waitForExistence(timeout: 5))
    }
}
