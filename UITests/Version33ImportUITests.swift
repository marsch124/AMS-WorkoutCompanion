import XCTest

/// 3.3: Import from a web page — offline with the demo page (-importdemo), found by identifier.
final class Version33ImportUITests: XCTestCase {
    func testImportTwoMachinesFromThePage() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-importdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["gym-import"].waitForExistence(timeout: 5))
        app.buttons["gym-import"].tap()

        let field = app.textFields["import-url"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("example.com/machines")
        app.buttons["import-find"].tap()

        XCTAssertTrue(app.buttons["import-item-0"].waitForExistence(timeout: 5))
        app.buttons["import-item-0"].tap()
        app.buttons["import-item-1"].tap()
        XCTAssertEqual(app.buttons["import-add"].label, "Add 2 machines")
        app.buttons["import-add"].tap()

        // The demo page's first machine is "Leg press"; the gym demo already has a tile of that name,
        // so check the sheet closed and the gym screen shows the tile.
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["import-add"].exists)
    }
}
