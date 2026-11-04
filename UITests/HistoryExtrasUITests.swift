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
        replace(reps, with: "7")
        app.buttons["visit-set-save"].tap()
        XCTAssertTrue(app.buttons["visit-set-1-1"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.buttons["visit-set-1-1"].label, before)
        XCTAssertTrue(app.buttons["visit-set-1-1"].label.hasSuffix("7"), app.buttons["visit-set-1-1"].label + " was " + before)
    }

    /// 1.11.2: tap Time on an earlier visit, type the real minutes, Save — the visit shows them.
    func testSetTheTimeOfAnEarlierVisitByHand() {
        app.buttons["history-row-1"].tap()
        let time = any("visit-time")
        XCTAssertTrue(time.waitForExistence(timeout: 10))
        time.tap()
        let minutes = app.textFields["visit-time-minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["visit-time-cancel"].exists)
        replace(minutes, with: "31")
        app.buttons["visit-time-save"].tap()
        XCTAssertTrue(any("visit-time").waitForExistence(timeout: 5))
        XCTAssertEqual(any("visit-time").label, "31 min")
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

    /// 1.11.1: the share picture carries each machine's photo (made-up photos: -tallphotos).
    func testSharePictureHoldsTheMachinePhotos() {
        app.terminate()
        app.launchArguments = ["-uitest", "-gymdemo", "-tallphotos"]
        app.launch()
        app.buttons["open-history"].tap()
        let row = app.buttons["history-row-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let share = app.buttons["visit-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        // The latest demo visit: Chest press, Lat pulldown and Treadmill — three photos.
        XCTAssertEqual(share.value as? String, "3 photos")
    }

    /// Clears a field key by key, then types — a double tap does not always select on GitHub's simulator.
    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()                                                              // focus
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()   // cursor after the number
        let old = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2) + text)
    }
}
