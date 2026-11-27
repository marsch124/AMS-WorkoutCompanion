import XCTest

/// 3.3 (his asks from screenshots, his picks 3 and 6 of a numbered picture): last time beside today,
/// the rest buttons on the ring, the keyboard on Weight when a rest starts, coloured Easy/OK/Hard.
final class Version33MachineUITests: XCTestCase {
    private var app: XCUIApplication!
    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testLastTimeBesideTodayRingButtonsAndKeyboard() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymdemo", "-restkeyboard"]
        app.launch()
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()

        // One box: last time's sets in their own column, each with its own kg.
        XCTAssertTrue(any("gym-compare").waitForExistence(timeout: 5))
        XCTAssertTrue(any("gym-last").label.hasPrefix("Last time ·"), any("gym-last").label)
        XCTAssertTrue(any("gym-last-1").exists)
        XCTAssertTrue(any("gym-last-1").label.contains("kg") || any("gym-last-1").label.contains("BW"), any("gym-last-1").label)
        shot("33-machine-before")

        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 5), "today's set in the Today column")

        // The rest starts with the keyboard on Weight, the number picked: typing replaces it.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard opens by itself")
        app.typeText("50")
        XCTAssertEqual(app.textFields["gym-rest-weight"].value as? String, "50")
        shot("33-rest-keyboard")
        app.buttons["keyboard-next"].tap()
        app.typeText("8")
        XCTAssertEqual(app.textFields["gym-rest-reps"].value as? String, "8")
        app.buttons["keyboard-done"].tap()

        // −15, Skip and +15 sit on the bottom of the ring.
        let ring = any("gym-rest-ring").frame
        let less = app.buttons["gym-rest-less"].frame, skip = app.buttons["gym-rest-skip"].frame
        let more = app.buttons["gym-rest-more"].frame
        XCTAssertLessThan(less.midX, skip.midX)
        XCTAssertLessThan(skip.midX, more.midX)
        XCTAssertGreaterThan(skip.midY, ring.midY, "Skip below the middle of the ring")
        XCTAssertLessThan(skip.minY, ring.maxY, "Skip touches the ring")
        XCTAssertLessThan(less.minY, ring.maxY)

        // Easy is green, chosen; the set says so.
        app.buttons["gym-effort-easy"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].label.contains("easy"), app.buttons["gym-set-1"].label)
        shot("33-rest-ring")

        app.buttons["gym-rest-skip"].tap()
        XCTAssertEqual(app.textFields["gym-weight"].value as? String, "50")
        XCTAssertEqual(app.textFields["gym-reps"].value as? String, "8")

        // Back on the gym screen: Done this session and the bigger search.
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(any("gym-done-list").waitForExistence(timeout: 5))
        shot("33-gym")
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
