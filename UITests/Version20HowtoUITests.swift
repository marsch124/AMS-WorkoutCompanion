import XCTest

/// 2.0: the small picture beside the machine name opens how to use it, full screen.
final class Version20HowtoUITests: XCTestCase {
    func testHowToThumbOpensAndCloses() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
        app.buttons["machine-Leg press"].tap()
        let thumb = app.buttons["machine-howto-thumb"]
        XCTAssertTrue(thumb.waitForExistence(timeout: 5))
        thumb.tap()
        XCTAssertTrue(app.buttons["howto-close"].waitForExistence(timeout: 5))
        app.buttons["howto-close"].tap()
        XCTAssertTrue(app.buttons["machine-howto-thumb"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["howto-close"].exists)
    }
}
