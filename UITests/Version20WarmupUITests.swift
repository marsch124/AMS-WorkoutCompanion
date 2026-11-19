import XCTest

/// 2.0 warm-up: the Warm up tile → chooser → Start → Done leaves the chip on the gym page;
/// the end alert offers Stretch now. Written by identifier; run by the lead after the merge.
final class Version20WarmupUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testWarmUpStartThenDoneLeavesTheChip() {
        let card = app.buttons["open-gym"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let tile = app.buttons["gym-warmup"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "the Warm up tile is on the gym page")
        tile.tap()
        XCTAssertTrue(any("warmup-minutes").waitForExistence(timeout: 5) || any("warmup-choose-moves").exists)
        XCTAssertTrue(app.buttons["warmup-cancel"].exists)
        app.buttons["warmup-choose-outside"].tap()
        app.buttons["warmup-start"].tap()
        XCTAssertTrue(any("warmup-clock").waitForExistence(timeout: 5), "the countdown shows")
        app.buttons["warmup-plus"].tap()
        app.buttons["warmup-done"].tap()
        XCTAssertTrue(any("gym-warmup-chip").waitForExistence(timeout: 5), "the chip stays on the gym page")
        XCTAssertFalse(app.buttons["gym-warmup"].exists, "no second Warm up tile once it is done")
    }

    func testTheEndAlertOffersStretchNow() {
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        app.buttons["gym-session-end"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Stretch now"].exists)
        XCTAssertTrue(alert.buttons["End session"].exists)
        XCTAssertTrue(alert.buttons["Continue the session"].exists)
        XCTAssertFalse(alert.buttons["Cancel"].exists)
    }
}
