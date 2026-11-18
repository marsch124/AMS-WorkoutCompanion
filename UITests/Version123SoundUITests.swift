import XCTest

/// 1.23: the Sounds screen, found by identifier.
final class Version123SoundUITests: XCTestCase {
    func testChooseBellAndSave() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        app.buttons["open-settings"].tap()
        let row = app.buttons["settings-sounds"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let bell = app.buttons["sounds-sound-bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        bell.tap()
        XCTAssertTrue(app.switches["sounds-spoken"].exists)
        app.buttons["sounds-save"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
