import XCTest

/// 1.24: Settings → Garmin Board, found by identifier.
final class Version124UITests: XCTestCase {
    func testTheGarminBoardPage() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        app.buttons["open-settings"].tap()
        let row = app.buttons["settings-board"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["board-choose"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["board-stop"].exists, "nothing is shared before a folder is chosen")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "124-board"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["board-done"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
