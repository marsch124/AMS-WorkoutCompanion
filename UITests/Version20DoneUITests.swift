import XCTest

/// 2.0: the Well done page shows the trophy and the week count.
final class Version20DoneUITests: XCTestCase {
    func testWellDoneShowsTrophyAndWeek() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
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
        XCTAssertTrue(app.descendants(matching: .any)["done-trophy"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["done-week"].firstMatch.exists)
    }
}
