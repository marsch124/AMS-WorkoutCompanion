import XCTest

extension XCUIApplication {
    /// Since 1.27 End and Finish this session ask first: tap "End session" in the box.
    func confirmEnd(file: StaticString = #filePath, line: UInt = #line) {
        let box = alerts.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5), "the End this session? box shows", file: file, line: line)
        box.buttons["End session"].firstMatch.tap()
    }
}
