import XCTest

/// 1.33 (his asks): weight and reps typed by hand, and no swipe that leaves the machine page.
final class Version133UITests: XCTestCase {
    func testTypeWeightAndRepsAndNoSwipeBack() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo"]
        app.launch()
        shot("133-home")
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        let kg = app.textFields["gym-weight"]
        XCTAssertTrue(kg.waitForExistence(timeout: 5))
        shot("133-machine")

        // A sideways slide on the page no longer goes back to the gym.
        app.swipeRight()
        XCTAssertTrue(kg.waitForExistence(timeout: 2), "still on the machine page after a swipe")

        // A tap beside the digits opens the keyboard with the number selected; typing replaces it.
        let minus = app.buttons["gym-weight-minus"].frame, plus = app.buttons["gym-weight-plus"].frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: minus.maxX + 12, dy: minus.midY)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.typeText("42")
        XCTAssertEqual(kg.value as? String, "42")
        XCTAssertLessThan(minus.maxX, plus.minX)

        let reps = app.textFields["gym-reps"]
        reps.tap()
        app.typeText("7")
        XCTAssertEqual(reps.value as? String, "7")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gym-set-1"].label.contains("42"), app.buttons["gym-set-1"].label)

        // During the rest: weight and reps can be typed too.
        let restReps = app.textFields["gym-rest-reps"]
        XCTAssertTrue(restReps.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["gym-rest-weight"].exists)
        restReps.tap()
        app.typeText("9")
        XCTAssertEqual(restReps.value as? String, "9")
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = "133-rest"; a.lifetime = .keepAlways; add(a)
        app.buttons["Done"].firstMatch.tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["gym-rest-skip"].waitForExistence(timeout: 3))
        shot("133-restbuttons")
        app.buttons["gym-rest-skip"].tap()
        XCTAssertEqual(app.textFields["gym-reps"].value as? String, "9")
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
