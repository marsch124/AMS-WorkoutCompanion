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
        // Two machines the demo gym does not have yet, found by their names.
        func item(_ name: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'import-item-' AND label BEGINSWITH %@", name)).firstMatch
        }
        item("Rowing machine").tap()
        XCTAssertTrue(item("Rowing machine").label.hasSuffix("ticked"), item("Rowing machine").label)
        // The lower cards can sit under the bottom bar: bring them up first.
        app.swipeUp()
        item("Seated leg curl").tap()
        XCTAssertTrue(item("Seated leg curl").label.hasSuffix("ticked"), item("Seated leg curl").label)
        XCTAssertEqual(app.buttons["import-add"].label, "Add 2 machines")
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "33-import"; a.lifetime = .keepAlways; add(a)
        app.buttons["import-add"].tap()

        // Back on the gym screen with the two new machines.
        XCTAssertTrue(app.buttons["machine-Rowing machine"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["machine-Seated leg curl"].exists)
        XCTAssertFalse(app.buttons["import-add"].exists)
    }
}
