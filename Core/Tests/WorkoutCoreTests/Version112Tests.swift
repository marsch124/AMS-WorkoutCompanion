import XCTest
@testable import WorkoutCore

/// Version 1.11.2: a visit's time runs from the first set to the last set, not to a late Finish.
final class Version112Tests: XCTestCase {
    let gym = UUID()
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()

    private func at(_ h: Int, _ m: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: h, minute: m))! }

    private func visitWithSets() -> (GymLog, GymVisit) {
        let press = Machine(gymID: gym, name: "Press")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(press)
        let day = at(10, 0)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: day, now: at(10, 0), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: day, now: at(10, 15), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: day, now: at(10, 32), calendar: cal)
        return (l, l.visit(on: day, gym: gym, calendar: cal)!)
    }

    func testFinishTappedHoursLaterDoesNotCountTheHoursAfterTheLastSet() {
        var (l, v) = visitWithSets()
        l.finish(visit: v.id, at: at(17, 10), calendar: cal)   // Finish at home, hours later
        v = l.visits.first { $0.id == v.id }!
        XCTAssertEqual(v.minutes, 32, "first set 10:00 → last set 10:32, not 7 hours")
    }

    func testFinishRightAfterTheLastSetStillCounts() {
        var (l, v) = visitWithSets()
        l.finish(visit: v.id, at: at(10, 36), calendar: cal)
        v = l.visits.first { $0.id == v.id }!
        XCTAssertEqual(v.minutes, 36)
    }

    func testTimeShowsEvenWithoutFinish() {
        let (_, v) = visitWithSets()
        XCTAssertEqual(v.minutes, 32)
    }

    func testSetsRememberWhenTheyWereDone() {
        let (_, v) = visitWithSets()
        XCTAssertEqual(v.entries[0].sets.map(\.at), [at(10, 0), at(10, 15), at(10, 32)])
    }

    func testOldVisitWithoutSetTimesAndAnImpossibleLengthShowsNoTime() {
        let v = GymVisit(gymID: gym, date: at(10, 0), entries: [], started: at(10, 0), finished: at(16, 38))
        XCTAssertNil(v.minutes, "6 h 38 from an old visit is a forgotten Finish, not a workout")
        let ok = GymVisit(gymID: gym, date: at(10, 0), entries: [], started: at(10, 0), finished: at(11, 10))
        XCTAssertEqual(ok.minutes, 70)
    }

    func testTimeSetByHandWinsAndCountsInHistory() {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        let v = GymVisit(gymID: gym, date: at(10, 0), entries: [MachineEntry(machineID: UUID(), sets: [GymSet(kg: 30, reps: 10)])],
                         started: at(10, 0), finished: at(16, 38))
        l.put(v)
        XCTAssertNil(l.visits[0].minutes)
        l.setMinutes(visit: v.id, 30)
        XCTAssertEqual(l.visits[0].minutes, 30)
        XCTAssertEqual(History.items(records: [], gym: l).first?.minutes, 30)
        l.setMinutes(visit: v.id, nil)
        XCTAssertNil(l.visits[0].minutes, "nil goes back to the worked-out time")
        l.setMinutes(visit: v.id, 0)
        XCTAssertNil(l.visits[0].minutesByHand, "0 minutes is no time")
    }
}
