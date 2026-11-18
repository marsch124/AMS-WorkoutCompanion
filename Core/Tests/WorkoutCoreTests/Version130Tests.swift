import XCTest
@testable import WorkoutCore

/// 1.30: Save as template from the finished session.
final class Version130Tests: XCTestCase {
    func testTheTemplateTakesThisSessionsMachinesInTheirOrder() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let at = { (h: Int) in cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: h))! }
        var log = GymLog()
        log.ensureGym()
        let gym = log.gyms[0].id
        let a = Machine(gymID: gym, name: "Leg press"), b = Machine(gymID: gym, name: "Rower"), c = Machine(gymID: gym, name: "Dips")
        [a, b, c].forEach { log.save($0) }
        log.add(GymSet(kg: 0, reps: 10), machine: c.id, on: at(17), calendar: cal)
        log.add(GymSet(kg: 30, reps: 10), machine: a.id, on: at(18), calendar: cal)
        log.add(GymSet(kg: 0, reps: 12), machine: c.id, on: at(19), calendar: cal)
        let visit = log.visits(in: gym)[0]
        XCTAssertEqual(visit.templateOrder(in: log), [c.id, a.id])
        log.delete(machine: c.id)
        XCTAssertEqual(visit.templateOrder(in: log), [a.id])
    }

    func testDiscardThrowsTheSessionAway() {
        var log = GymLog()
        log.ensureGym()
        let gym = log.gyms[0].id
        let a = Machine(gymID: gym, name: "Leg press")
        log.save(a)
        let now = Date()
        log.arrive(gym: gym, at: now)
        log.add(GymSet(kg: 30, reps: 10), machine: a.id, on: now)
        log.setPlan([a.id], on: now, gym: gym)
        let v = log.visits(in: gym)[0]
        log.discard(visit: v.id)
        XCTAssertTrue(log.visits.isEmpty)
        XCTAssertNil(log.sessionStart(on: now, gym: gym))
        XCTAssertNil(log.plan(on: now, gym: gym))
    }

    func testSevenStretchListsEachWithAGuide() {
        let all = StretchRoutine.all
        XCTAssertEqual(all.count, 7, "the app's own plus six more")
        XCTAssertEqual(Set(all.map(\.id)).count, 7)
        XCTAssertEqual(all[0].moves.map(\.name), Workout.afterGymStretch().exercises.map(\.name))
        let names = all.flatMap(\.moves).map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "each stretch once, so its guide is found by name")
        for m in all.flatMap(\.moves) {
            XCTAssertGreaterThanOrEqual(m.steps.count, 3, m.name)
            XCTAssertFalse(m.feel.isEmpty || m.careful.isEmpty, m.name)
            XCTAssertEqual(StretchRoutine.move(named: m.name), m)
        }
        let w = all[3].workout()
        XCTAssertEqual(w.id, all[3].id)
        XCTAssertEqual(w.kind, .checklist)
        XCTAssertEqual(w.exercises.count, all[3].moves.count)
    }
}
