import XCTest

/// 1.15: a rest at the gym also shows on the lock screen and in the Dynamic Island.
/// The system's own island cannot be read by a test, so the rest card says
/// "Also on your lock screen" exactly while the phone holds the rest out there.
final class RestLiveUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testARestShowsOnTheLockScreenAndSkippingEndsIt() {
        app.buttons["open-gym"].tap()
        let machine = app.buttons["machine-Leg press"]
        XCTAssertTrue(machine.waitForExistence(timeout: 5))
        machine.tap()
        let done = app.buttons["gym-set-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        let lock = any("gym-rest-lock")
        XCTAssertTrue(lock.waitForExistence(timeout: 5), "the rest is on the lock screen")

        // It stays out there while another app is in front.
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(lock.waitForExistence(timeout: 5), "still there after coming back")

        app.buttons["gym-rest-skip"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("gym-rest-lock").exists, "a skipped rest leaves the lock screen")
    }
}
