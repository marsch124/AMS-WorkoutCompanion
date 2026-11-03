import XCTest

/// Replays a problem with a gym file from the Mac (never committed: skipped unless REPLAY_GYM is set).
final class ReplayUITests: XCTestCase {
    func testPlanInTheCurrentGym() throws {
        let path = ProcessInfo.processInfo.environment["REPLAY_GYM"] ?? ""
        try XCTSkipIf(path.isEmpty, "Only when replaying")
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-gymfile", path]
        app.launch()
        app.buttons["open-gym"].tap()
        let plan = app.buttons["gym-plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        Thread.sleep(forTimeInterval: 1)
        add(XCTAttachment(screenshot: app.screenshot()))
        for n in ["Dumbbell", "Hantel", "Vitruvian"] {
            let b = app.buttons["plan-machine-\(n)"]
            XCTAssertTrue(b.waitForExistence(timeout: 3), n)
            b.tap()
        }
        add(XCTAttachment(screenshot: app.screenshot()))
        app.buttons["plan-save"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        let dump = XCTAttachment(string: app.debugDescription); dump.lifetime = .keepAlways; add(dump)
        XCTAssertTrue(app.buttons["plan-row-3"].waitForExistence(timeout: 3), "only some rows")
        app.buttons["plan-row-1"].tap()
        XCTAssertTrue(app.buttons["gym-set-done"].waitForExistence(timeout: 5))
        app.buttons["gym-set-done"].tap()
        if app.buttons["gym-rest-skip"].waitForExistence(timeout: 3) { app.buttons["gym-rest-skip"].tap() }
        let next = app.buttons["gym-machine-done"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        let a1 = XCTAttachment(string: "next label: " + next.label); a1.lifetime = .keepAlways; add(a1)
        next.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let s2 = XCTAttachment(screenshot: app.screenshot()); s2.lifetime = .keepAlways; add(s2)
        XCTAssertTrue(app.navigationBars["Hantel"].waitForExistence(timeout: 3), "did not move on to Hantel")
    }
}
