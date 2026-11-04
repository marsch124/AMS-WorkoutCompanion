import XCTest
@testable import WorkoutCore

/// Version 1.14: Undo Finish and delete a session.
final class Version114Tests: XCTestCase {
    let gym = UUID()

    private func log() -> (GymLog, UUID, UUID) {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        let press = Machine(gymID: gym, name: "Press")
        let leg = Machine(gymID: gym, name: "Leg")
        l.save(press)
        l.save(leg)
        l.add(GymSet(kg: 20, reps: 10), machine: press.id, on: Date())
        return (l, press.id, leg.id)
    }

    func testUndoFinishOpensTheSessionWithItsPlanAndBusyMarks() {
        var (l, press, leg) = log()
        l.setBusy(leg, true, on: Date())
        l.setPlan([press, leg], on: Date(), gym: gym)
        let v = l.visits[0].id
        let before = l
        l.finish(visit: v)
        XCTAssertNotNil(l.visits[0].finished)
        XCTAssertTrue(l.busyMarks.isEmpty)
        l.describe(visit: v, title: "Push", notes: "")
        l.undoFinish(visit: v, before: before)
        XCTAssertNil(l.visits[0].finished, "the session is open again")
        XCTAssertEqual(l.busyMarks.count, 1, "Busy marks come back")
        XCTAssertEqual(l.plans.count, before.plans.count, "the plan comes back")
        XCTAssertEqual(l.visits[0].title, "Push", "words written since stay")
        XCTAssertEqual(l.openVisit(on: Date(), gym: gym)?.id, v, "the next set goes into the same session")
    }

    func testDeleteASession() {
        var (l, press, _) = log()
        let first = l.visits[0].id
        l.finish(visit: first)
        l.add(GymSet(kg: 22, reps: 8), machine: press, on: Date())
        XCTAssertEqual(l.visits.count, 2)
        l.delete(visit: first)
        XCTAssertEqual(l.visits.count, 1)
        XCTAssertFalse(l.visits.contains { $0.id == first })
    }
}
