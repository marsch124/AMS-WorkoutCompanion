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

    /// Martin's placement (asked for in 1.13, lost in 1.16): the Busy pill sits bottom right of
    /// the photo, just above the name band — marked or not. This test stops it moving again.
    func testBusyPillSitsBottomRightAboveTheNameBand() {
        for state in ["not busy", "busy"] {
            let tile = app.buttons["machine-Leg press"]
            let pill = app.buttons["busy-Leg press"]
            let band = any("tile-band-Leg press")
            XCTAssertTrue(band.waitForExistence(timeout: 5))
            let t = tile.frame, p = pill.frame, b = band.frame
            XCTAssertGreaterThan(p.midX, t.midX, "\(state): pill should be on the right — \(p) in \(t)")
            XCTAssertGreaterThan(p.midY, t.midY, "\(state): pill should be in the bottom half — \(p) in \(t)")
            XCTAssertLessThanOrEqual(p.maxX, t.maxX + 1, "\(state): pill inside the tile")
            XCTAssertLessThanOrEqual(p.maxY, b.minY + 1, "\(state): pill above the name band — \(p) band \(b)")
            if state == "not busy" {
                pill.tap()
                XCTAssertTrue(app.buttons["Leg press is busy"].waitForExistence(timeout: 5))
            }
        }
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

    // MARK: 1.17

    /// His ask (5 Nov): the three action tiles smaller — they were ~84 pt tall.
    func testActionTilesAreCompact() {
        for id in ["gym-plan", "gym-repeat", "gym-repeat-template"] {
            let tile = app.buttons[id]
            XCTAssertTrue(tile.waitForExistence(timeout: 5), id)
            XCTAssertLessThanOrEqual(tile.frame.height, 52, "\(id) is \(tile.frame.height) pt tall")
        }
    }

    /// His ask (5 Nov): show that a session is going. No line before the first set; after it,
    /// "Session going" at the top of the gym screen. Finish takes it away again.
    func testTheGymScreenSaysASessionIsGoing() {
        // Since 1.20 the session starts when the gym opens (his ask): the line is there before any set.
        let first = any("gym-session-going")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.contains("no sets yet"), first.label)
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        let going = any("gym-session-going")
        XCTAssertTrue(going.waitForExistence(timeout: 5))
        XCTAssertTrue(going.label.contains("Session going"), going.label)
        XCTAssertTrue(going.label.contains("1 set"), going.label)
    }

    // MARK: 1.18

    /// His ask (5 Nov): the Train page shows a session is going too, under the At the gym card.
    func testTheTrainPageSaysASessionIsGoing() {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["open-gym"].waitForExistence(timeout: 5))
        // Since 1.20 opening the gym (done in setUp) already started the session.
        let early = any("home-session-going")
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        XCTAssertTrue(early.label.contains("no sets yet"), early.label)
        app.buttons["open-gym"].tap()
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let going = any("home-session-going")
        XCTAssertTrue(going.waitForExistence(timeout: 5))
        XCTAssertTrue(going.label.contains("Session going"), going.label)
        XCTAssertTrue(going.label.contains("min"), going.label)
        // Tapping it opens the gym.
        going.tap()
        XCTAssertTrue(any("gym-session-going").waitForExistence(timeout: 5))
    }

    /// His ask (5 Nov): the Finish button, seen when scrolled down, carries the session's minutes.
    func testTheFinishButtonShowsTheSessionMinutes() {
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        app.buttons["machine-done-pill"].tap()
        let finish = app.buttons["gym-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        XCTAssertEqual(finish.label, "Finish this session")
        let minutes = finish.value as? String ?? ""
        XCTAssertTrue(minutes.hasSuffix(" min"), "value was \"\(minutes)\"")
    }

    // MARK: 1.19

    /// His report (5 Nov): opening a machine left no way out but Set done or Exercise done.
    /// With no set yet the bottom button says "Back to gym" (his word, 1.20; "Back to machines" in 1.19) and logs nothing; after a set it says "Exercise done".
    func testAMachineCanBeLeftWithoutLoggingASet() {
        app.buttons["machine-Leg press"].tap()
        let bottom = app.buttons["machine-done-pill"]
        XCTAssertTrue(bottom.waitForExistence(timeout: 5))
        XCTAssertEqual(bottom.label, "Back to gym")
        bottom.tap()
        XCTAssertTrue(app.buttons["machine-Leg press"].waitForExistence(timeout: 5))
        XCTAssertTrue(any("gym-session-going").label.contains("no sets yet"), "leaving without a set saves no set")
        app.buttons["machine-Leg press"].tap()
        app.buttons["gym-set-done"].tap()
        XCTAssertTrue(app.buttons["gym-set-1"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["machine-done-pill"].label, "Exercise done")
    }

    // MARK: 1.20

    /// His ask (5 Nov): "Session going" from opening the gym. Finish with no set ends it and saves nothing.
    func testFinishWithoutASetEndsTheSession() {
        let finish = app.buttons["gym-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertFalse(any("gym-session-going").waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["gym-finish"].exists)
        XCTAssertFalse(any("gym-earlier-day").exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["open-gym"].waitForExistence(timeout: 5))
        XCTAssertFalse(any("home-session-going").exists)
    }
}
