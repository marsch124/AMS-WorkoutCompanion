import XCTest

/// 3.3: the planning board on a wide screen (iPad, the Mac).
final class Version33BoardUITests: XCTestCase {
    func testPlanTwoMachinesOnTheBoard() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .phone, "the board is for the iPad and the Mac")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-gymextras"]
        app.launch()
        app.buttons["side-gym"].tap()
        let open = app.buttons["gym-board"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["board-screen"].waitForExistence(timeout: 5))

        let first = app.buttons["board-machine-Chest press"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        let second = app.buttons["board-machine-Leg press"]
        XCTAssertTrue(second.waitForExistence(timeout: 2))
        second.tap()

        XCTAssertTrue(app.descendants(matching: .any)["board-plan-1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["board-plan-2"].waitForExistence(timeout: 3))
        app.buttons["board-save"].tap()

        // The gym screen shows the plan.
        XCTAssertTrue(app.descendants(matching: .any)["plan-row-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["plan-row-2"].exists)
    }
}
