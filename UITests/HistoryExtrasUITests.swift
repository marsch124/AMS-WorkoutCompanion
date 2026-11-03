import XCTest

/// 1.11: fix a set afterwards, the records wall and search my notes — found by identifier, with made-up data (-gymdemo).
final class HistoryExtrasUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-history"].tap()
    }

    func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testChangeASetOnAnEarlierVisit() {
        XCTAssertTrue(any("stats-muscle-balance").waitForExistence(timeout: 10))
        XCTAssertTrue(any("muscle-balance-chest").exists)
        app.buttons["history-row-1"].tap()
        let chip = app.buttons["visit-set-1-1"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["visit-share"].waitForExistence(timeout: 10))
        let before = chip.label
        chip.tap()
        let reps = app.textFields["visit-set-reps"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        XCTAssertTrue(any("visit-set-remove").exists)
        reps.doubleTap()   // selects the number
        reps.typeText("7")
        app.buttons["visit-set-save"].tap()
        XCTAssertTrue(app.buttons["visit-set-1-1"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.buttons["visit-set-1-1"].label, before)
        XCTAssertTrue(app.buttons["visit-set-1-1"].label.hasSuffix("7"), app.buttons["visit-set-1-1"].label + " was " + before)
    }

    func testRecordsWall() {
        let open = app.buttons["open-records"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(any("records-row-1").waitForExistence(timeout: 5))
    }

    func testSearchMyNotes() {
        let open = app.buttons["open-notes-search"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let field = app.textFields["notes-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Seat")   // a machine's setting in the demo data
        XCTAssertTrue(any("notes-hit-1").waitForExistence(timeout: 5))
    }
}
