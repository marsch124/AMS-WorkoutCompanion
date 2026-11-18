import XCTest

/// 1.29: the gym's name pill opens the gym chooser plate — every gym a row with its photo, four
/// buttons and Done — instead of Apple's plain menu.
final class Version129UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-tallphotos"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["gym-place-menu"].waitForExistence(timeout: 5))
    }

    private func picture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testThePillOpensThePlateWithGymsButtonsAndDone() {
        // A second gym, without a photo, made from the plate.
        app.buttons["gym-place-menu"].tap()
        XCTAssertTrue(app.buttons["gym-place-new"].waitForExistence(timeout: 5))
        app.buttons["gym-place-new"].tap()
        let name = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5), "New gym closes the plate and asks for the name")
        name.typeText("Basic-Fit Benalmadena")
        app.alerts.firstMatch.buttons["Save"].firstMatch.tap()

        // The plate: both gyms, the one in use marked, a photo square each, four buttons, Done.
        app.buttons["gym-place-menu"].tap()
        let here = app.buttons["gym-place-Basic-Fit Benalmadena"]
        XCTAssertTrue(here.waitForExistence(timeout: 5))
        XCTAssertEqual(here.label, "Basic-Fit Benalmadena, here now")
        XCTAssertEqual(app.buttons["gym-place-My gym"].label, "My gym")
        XCTAssertTrue(app.buttons["gym-photo-My gym"].exists)
        XCTAssertTrue(app.buttons["gym-photo-Basic-Fit Benalmadena"].exists)
        for id in ["gym-place-new", "gym-place-rename", "gym-place-hours", "gym-pick-day", "gym-place-done"] {
            XCTAssertTrue(app.buttons[id].exists, id)
        }
        picture("129-plate")

        // Done closes it and changes nothing.
        app.buttons["gym-place-done"].tap()
        XCTAssertFalse(app.buttons["gym-place-done"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["gym-place-menu"].label, "Gym: Basic-Fit Benalmadena")

        // A tap on a gym switches to it and closes the plate.
        app.buttons["gym-place-menu"].tap()
        XCTAssertTrue(app.buttons["gym-place-My gym"].waitForExistence(timeout: 5))
        app.buttons["gym-place-My gym"].tap()
        XCTAssertTrue(app.buttons["machine-Chest press"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["gym-place-menu"].label, "Gym: My gym")
    }
}
