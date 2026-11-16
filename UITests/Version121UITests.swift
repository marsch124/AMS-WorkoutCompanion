import XCTest

/// 1.21: a workouts file that cannot be read shows a red note on Train, with the way to Backups.
final class Version121UITests: XCTestCase {
    func testAnUnreadableWorkoutsFileShowsTheNoteAndOpensBackups() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-unreadable"]
        app.launch()
        let note = app.staticTexts["unreadable-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertEqual(note.label, "Your workouts could not be read")
        app.descendants(matching: .any)["unreadable-backups"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Backups"].waitForExistence(timeout: 5))
    }
}
