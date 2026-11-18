import XCTest

extension XCUIApplication {
    /// Since 1.30 Earlier visits are folded away: scroll to the toggle and open it (if closed).
    func showEarlierVisits(file: StaticString = #filePath, line: UInt = #line) {
        let toggle = buttons["gym-earlier-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "the Earlier visits toggle shows", file: file, line: line)
        for _ in 0..<10 where !toggle.isHittable { swipeUp() }
        if (toggle.value as? String)?.hasPrefix("Hidden") == true { toggle.tap() }
        XCTAssertTrue(buttons["gym-visit-1"].waitForExistence(timeout: 5), "the list opens", file: file, line: line)
    }
}
