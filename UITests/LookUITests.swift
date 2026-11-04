import XCTest

/// 1.16 look: photo tiles with a name band, a rest ring that changes colour, and sets
/// that beat last time marked with an arrow. Made-up data (-gymdemo), found by identifier.
final class LookUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        app.buttons["open-gym"].tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testTilesCarryTheNameOnABandOverThePhoto() {
        XCTAssertTrue(any("tile-band-Leg press").waitForExistence(timeout: 5))
        // The Busy pill still works on the new tile.
        app.buttons["busy-Leg press"].tap()
        XCTAssertTrue(app.buttons["Leg press is busy"].waitForExistence(timeout: 5))
    }

    func testRestRingStartsOrange() {
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        let ring = any("gym-rest-ring")
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertEqual(ring.value as? String, "orange")
    }

    func testAHeavierSetThanLastTimeGetsAnArrow() {
        app.buttons["machine-Leg press"].tap()
        let plus = app.buttons["gym-weight-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        for _ in 0..<4 { plus.tap() }          // last time 55 kg — now 65 kg
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gym-set-1"].label.contains("more than last time"), app.buttons["gym-set-1"].label)
    }
}
