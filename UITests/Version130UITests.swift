import XCTest

/// 1.30: six more ready-made stretch lists and a stretch guide (his ask).
final class Version130UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
    }

    private func picture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testChooseAReadyMadeStretchListAndReadItsGuide() {
        app.buttons["open-settings"].tap()
        let row = app.buttons["settings-gym-extras"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let legs = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Legs after leg day'")).firstMatch
        for _ in 0..<6 where !legs.isHittable { app.swipeUp() }
        legs.tap()
        picture("130-stretch-lists")
        let guide = app.buttons["extras-stretch-guide"]
        for _ in 0..<6 where !guide.isHittable { app.swipeUp() }
        guide.tap()
        let first = app.descendants(matching: .any)["stretch-guide-1"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.contains("Where you feel it"), first.label)
        picture("130-stretch-guide")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["extras-save"].tap()
        // The list is now one of his exercise lists on Workouts.
        app.buttons["open-train"].tap()
        XCTAssertTrue(app.buttons["workout-Legs after leg day"].waitForExistence(timeout: 5))
    }
}
