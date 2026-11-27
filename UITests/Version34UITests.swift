import XCTest

/// 3.4 (his yes to two ideas after 3.3): the planning board on the iPhone, and no faint last-time line.
final class Version34UITests: XCTestCase {
    func testPlanningBoardOnTheIPhone() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the small board is the iPhone's")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
        app.buttons["open-gym"].tap()
        let open = app.buttons["gym-board"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()
        XCTAssertTrue(any("board-screen").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["board-machine-Chest press"].exists, "on the iPhone the machines wait in a sheet")

        app.buttons["board-add-machines"].tap()
        let chest = app.buttons["board-machine-Chest press"]
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        chest.tap()
        app.buttons["board-machine-Leg press"].tap()
        shot("34-add-machines")
        app.buttons["board-machines-done"].tap()

        XCTAssertTrue(any("board-plan-1").waitForExistence(timeout: 5))
        XCTAssertTrue(any("board-plan-2").exists)
        XCTAssertTrue(any("board-plan-1").staticTexts["Chest press"].exists)
        shot("34-board")
        app.buttons["board-save"].tap()

        // The gym screen shows the plan.
        XCTAssertTrue(any("plan-row-1").waitForExistence(timeout: 5))
        XCTAssertTrue(any("plan-row-2").exists)
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
