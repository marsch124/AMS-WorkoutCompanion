import XCTest
@testable import WorkoutCore

/// 1.34: a stretch session is saved even when stopped early, counting the chosen stretches.
final class Version134Tests: XCTestCase {
    func testAStretchStoppedEarlyIsStillSaved() {
        var w = Workout(name: "After-gym stretch", kind: .checklist)
        w.exercises = (1...6).map { Exercise(name: "S\($0)", amount: "30 s") }
        let t = Date()
        XCTAssertNil(SessionRecord.ofStretch(w, started: t, ended: t, held: 0, chosen: 6))
        let part = SessionRecord.ofStretch(w, started: t, ended: t, held: 2, chosen: 6)!
        XCTAssertEqual(part.detail, "2 of 6 stretches")
        XCTAssertFalse(part.completed)
        let chosen = SessionRecord.ofStretch(w, started: t, ended: t, held: 4, chosen: 4)!
        XCTAssertEqual(chosen.detail, "4 of 4 chosen stretches")
        XCTAssertTrue(chosen.completed)
    }
}
