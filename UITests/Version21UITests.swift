import XCTest

/// 2.1: the warm-up moves that suit today's machines are ticked and marked "suggested".
final class Version21UITests: XCTestCase {
    func testWarmUpMovesSuggestedForTodaysMachines() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Demo: the last visit did Chest press (chest) and Lat pulldown (back), no plan today.
        app.launchArguments = ["-uitest", "-gymdemo", "-gymextras"]
        app.launch()
        app.buttons["open-gym"].tap()
        let tile = app.buttons["gym-warmup-start"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.buttons["warmup-choose-moves"].waitForExistence(timeout: 5))
        app.buttons["warmup-choose-moves"].tap()
        let line = app.staticTexts["warmup-suggested-line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertEqual(line.label, "Suggested for today: chest, back")
        // Nothing remembered: the suggested moves come first, ticked; the others are not ticked.
        let first = app.buttons["warmup-move-1"]
        XCTAssertEqual(first.label, "Arm circles, suggested, ticked")
        let last = app.buttons["warmup-move-10"]
        app.reveal(last)
        XCTAssertTrue(last.label.hasSuffix("not ticked"), last.label)
        XCTAssertFalse(last.label.contains("suggested"), last.label)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "2.1 warm-up moves suggested"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
