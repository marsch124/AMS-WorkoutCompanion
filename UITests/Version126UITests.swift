import XCTest

/// 1.26: the new look "Cards and glass" — the gym's top is one card holding the buttons; the bottom bar is a capsule.
final class Version126UITests: XCTestCase {
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

    func testTheGymHeadCardHoldsTheButtonsAndTrainIsSelected() {
        let head = any("gym-head")
        XCTAssertTrue(head.waitForExistence(timeout: 5))
        let plan = any("gym-plan")
        let repeatLast = any("gym-repeat")
        XCTAssertTrue(plan.exists)
        XCTAssertTrue(repeatLast.exists)
        XCTAssertTrue(head.frame.contains(plan.frame), "gym-plan is inside gym-head")
        XCTAssertTrue(head.frame.contains(repeatLast.frame), "gym-repeat is inside gym-head")
        let train = app.buttons["open-train"]
        XCTAssertTrue(train.exists)
        XCTAssertTrue(train.isSelected)
        do { let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "126-gym"; a.lifetime = .keepAlways; add(a) }
    }
}
