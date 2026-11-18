import XCTest

/// 1.35 (his ask, he crossed it out on a screenshot): the At the gym card on Workouts no longer names the gym.
final class Version135UITests: XCTestCase {
    func testTheGymCardShowsNoGymName() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        let card = app.buttons["open-gym"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "At the gym", "only the heading, no gym name under it")
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "135-workouts"; a.lifetime = .keepAlways; add(a)
    }
}
