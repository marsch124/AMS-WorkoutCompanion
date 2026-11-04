import XCTest
@testable import WorkoutCore

/// Version 1.12: Finish closes a session; a set afterwards starts the day's second session.
final class TwoSessionsTests: XCTestCase {
    let gym = UUID()
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: hour, minute: minute))!
    }

    func testASetAfterFinishStartsASecondSessionThatDay() {
        let press = Machine(gymID: gym, name: "Press")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(press)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: at(8), now: at(8), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: at(8), now: at(8, 5), calendar: cal)
        let morning = l.visits[0].id
        l.finish(visit: morning, at: at(8, 10), calendar: cal)

        // Evening: a new session, the morning one untouched.
        l.add(GymSet(kg: 45, reps: 8), machine: press.id, on: at(18), now: at(18), calendar: cal)
        XCTAssertEqual(l.visits.count, 2)
        XCTAssertEqual(l.visits.first { $0.id == morning }?.setCount, 2)
        let evening = l.visits.first { $0.id != morning }!
        XCTAssertEqual(evening.setCount, 1)
        XCTAssertNil(evening.finished)
        XCTAssertEqual(evening.started, at(18))

        // The open session is the evening one; both count for the day, the latest first in the list.
        XCTAssertEqual(l.openVisit(on: at(19), gym: gym, calendar: cal)?.id, evening.id)
        XCTAssertEqual(l.visits(on: at(19), gym: gym, calendar: cal).map(\.id), [morning, evening.id])
        
        XCTAssertEqual(l.visitsNewestFirst.first?.id, evening.id)
        // Last time on the press in the evening is the morning session.
        XCTAssertEqual(l.last(press.id, excluding: evening.id)?.visit.id, morning)
        // A machine done in the morning is not "done" in the evening session yet.
        l.finish(visit: evening.id, at: at(18, 20), calendar: cal)
        XCTAssertNil(l.openVisit(on: at(19), gym: gym, calendar: cal))
        XCTAssertFalse(l.isDone(press.id, on: at(19), gym: gym, calendar: cal))
    }

    func testWithoutFinishTheSetsStayInOneSession() {
        let press = Machine(gymID: gym, name: "Press")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(press)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: at(8), now: at(8), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: at(8), now: at(9), calendar: cal)
        XCTAssertEqual(l.visits.count, 1)
        XCTAssertEqual(l.visits[0].setCount, 2)
    }
}
