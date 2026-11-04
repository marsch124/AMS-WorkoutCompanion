import XCTest

/// 1.10: plan templates, found by identifier, with made-up data (-gymdemo).
final class TemplatesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
    }

    func testSaveUseAndDeleteATemplate() {
        app.buttons["gym-plan"].tap()
        app.buttons["plan-machine-Leg press"].tap()
        app.buttons["plan-machine-Chest press"].tap()
        let save = app.buttons["plan-save-template"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let field = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Leg day")
        app.alerts.firstMatch.buttons["Save"].firstMatch.tap()
        app.buttons["plan-cancel"].tap()

        app.buttons["gym-plan"].tap()
        let row = app.buttons["plan-template-Leg day"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the template is not listed")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-order-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["plan-order-2"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["plan-order-3"].exists)

        // 1.14: no deleting in Plan today — that is in Settings → Plan templates.
        XCTAssertFalse(app.buttons["plan-template-delete-Leg day"].exists)
        app.buttons["plan-save"].tap()

        app.buttons["open-settings"].tap()
        app.buttons["open-templates"].tap()
        let delete = app.buttons["template-delete-Leg day"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the template is not in Settings")
        delete.tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 5), "the template is still there")
        app.buttons["open-train"].tap()
        app.buttons["gym-plan"].tap()
        XCTAssertFalse(app.buttons["plan-template-Leg day"].waitForExistence(timeout: 2), "deleted in Settings, gone from Plan today")
    }
}
