import XCTest

extension XCUIApplication {
    /// Since 1.27 End and Finish this session ask first: tap "End session" in the box.
    func confirmEnd(file: StaticString = #filePath, line: UInt = #line) {
        let box = alerts.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5), "the End this session? box shows", file: file, line: line)
        box.buttons["End session"].firstMatch.tap()
    }

    /// Scrolls down until the element is there (at most four swipes). Since 1.35 the Session done
    /// page starts with Stretch now and Save as template, so the numbers sit lower.
    func scrollTo(_ e: XCUIElement, timeout: TimeInterval = 5) {
        _ = descendants(matching: .any)["gym-summary-done"].firstMatch.waitForExistence(timeout: timeout)
        var swipes = 0
        while !e.exists && swipes < 4 {
            swipeUp()
            swipes += 1
        }
    }
}
