import XCTest

/// Version 1.10: Settings → Muscle groups.
final class MuscleGroupsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    func openGroups() {
        app.buttons["open-settings"].tap()
        let link = app.buttons["open-muscle-groups"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "no Muscle groups link in Settings")
        link.tap()
        XCTAssertTrue(app.buttons["muscle-add"].waitForExistence(timeout: 5))
    }

    func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        sleep(1)
    }

    func testAddRenameAndDeleteAGroup() {
        openGroups()
        app.buttons["muscle-add"].tap()
        let name = app.textFields["muscle-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Glutes")
        app.buttons["muscle-colour-plum"].tap()
        app.buttons["muscle-save"].tap()
        let row = app.buttons["muscle-row-Glutes"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Glutes not in the list")

        row.tap()
        let rename = app.textFields["muscle-name"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()
        rename.clearAndType("Hips")
        app.buttons["muscle-save"].tap()
        XCTAssertTrue(app.buttons["muscle-row-Hips"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["muscle-row-Glutes"].exists)

        // A new group is offered on a machine's edit page.
        app.buttons["open-train"].tap()
        let gym = app.buttons["open-gym"]
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        sleep(1)
        gym.tap()
        app.buttons["machine-Chest press"].tap()
        app.buttons["gym-edit-machine"].tap()
        let picker = app.buttons["machine-muscle"]
        for _ in 0..<4 where !picker.isHittable { app.swipeUp() }
        picker.tap()
        XCTAssertTrue(app.buttons["Hips"].firstMatch.waitForExistence(timeout: 5), "Hips not in the machine picker")
        app.buttons["Hips"].firstMatch.tap()
        app.buttons["machine-cancel"].tap()

        // Delete with confirmation.
        app.buttons["open-settings"].tap()
        if !app.buttons["muscle-add"].waitForExistence(timeout: 2) { openGroups() }
        let hips = app.buttons["muscle-row-Hips"]
        XCTAssertTrue(hips.waitForExistence(timeout: 5))
        hips.tap()
        app.buttons["muscle-delete"].tap()
        let confirm = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "delete did not ask first")
        confirm.tap()
        XCTAssertTrue(app.buttons["muscle-add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["muscle-row-Hips"].exists)
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        let current = (value as? String) ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
