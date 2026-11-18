import XCTest

/// 1.27: End on the green line is red and asks first ("Continue the session", not Cancel); the At the gym card
/// no longer counts the machines; the machine cards have no muscle stripe; the gym chooser is indigo.
final class Version127UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func picture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testEndAsksFirstAndTheCardDoesNotCountMachines() {
        let card = app.buttons["open-gym"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertNil(card.label.range(of: #"^At the gym, \d+ machines?$"#, options: .regularExpression),
                     "the card no longer says how many machines are set up: \(card.label)")
        picture("127-train")
        card.tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("tile-stripe-Leg press").exists, "no muscle stripe on the machine card")

        app.buttons["machine-Leg press"].tap()
        XCTAssertTrue(app.buttons["machine-done-pill"].waitForExistence(timeout: 5))
        picture("127-machine")
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5))
        picture("127-gym")

        // End asks; "Continue the session" keeps it going.
        app.buttons["gym-session-end"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(alert.buttons["Cancel"].exists)
        picture("127-ask")
        alert.buttons["Continue the session"].firstMatch.tap()
        XCTAssertTrue(app.buttons["gym-session-end"].waitForExistence(timeout: 5), "the session goes on")

        // End, then "End session": the session is over.
        app.buttons["gym-session-end"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["End session"].firstMatch.tap()
        XCTAssertFalse(app.buttons["gym-session-end"].waitForExistence(timeout: 2))
    }
}
