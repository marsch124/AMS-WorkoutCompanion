import XCTest

extension XCUIApplication {
    /// Since 1.27 End and Finish this session ask first: tap "End session" in the box.
    func confirmEnd(file: StaticString = #filePath, line: UInt = #line) {
        let box = alerts.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5), "the End this session? box shows", file: file, line: line)
        box.buttons["End session"].firstMatch.tap()
    }
}

extension XCUIApplication {
    /// 2.0: scroll in small steps until the element sits clear of the bottom button bar
    /// (a big swipe overshoots in a List, and a row under the bar is "hittable" but the tap lands on the bar).
    func reveal(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let bottom = frame.maxY - 150
        for _ in 0..<14 {
            if e.exists, e.isHittable, e.frame.maxY < bottom, e.frame.minY > 90 { return }
            let from = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            let to = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: e.exists && e.frame.minY <= 90 ? 0.85 : 0.48))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(e.exists, "\(e) shows", file: file, line: line)
    }
}
