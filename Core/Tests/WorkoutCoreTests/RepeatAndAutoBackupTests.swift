import XCTest
@testable import WorkoutCore

/// 1.7: Repeat last visit, and the automatic backup's timing.
final class RepeatAndAutoBackupTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()
    func day(_ d: Int, _ hour: Int = 18) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    func testRepeatTakesLastVisitsMachinesInTheirOrder() {
        var log = GymLog()
        log.ensureGym()
        let gym = log.gyms[0].id
        let a = Machine(gymID: gym, name: "Leg press"), b = Machine(gymID: gym, name: "Rower"), c = Machine(gymID: gym, name: "Dips")
        [a, b, c].forEach { log.save($0) }
        log.add(GymSet(kg: 40, reps: 10), machine: a.id, on: day(1), calendar: cal)
        log.add(GymSet(kg: 0, reps: 10), machine: c.id, on: day(2), calendar: cal)
        log.add(GymSet(kg: 30, reps: 10), machine: b.id, on: day(2, 19), calendar: cal)
        log.add(GymSet(kg: 0, reps: 12), machine: c.id, on: day(2, 20), calendar: cal)
        XCTAssertEqual(log.lastOrder(gym: gym, before: day(5), calendar: cal), [c.id, b.id])
        // Today's own sets do not count as "last visit".
        log.add(GymSet(kg: 40, reps: 10), machine: a.id, on: day(5), calendar: cal)
        XCTAssertEqual(log.lastOrder(gym: gym, before: day(5), calendar: cal), [c.id, b.id])
        // A deleted machine drops out; another gym has nothing to repeat.
        log.delete(machine: b.id)
        XCTAssertEqual(log.lastOrder(gym: gym, before: day(5), calendar: cal), [c.id])
        XCTAssertEqual(log.lastOrder(gym: UUID(), before: day(5), calendar: cal), [])
    }

    func testAutomaticBackupIsDueOncePerDay() {
        XCTAssertTrue(Backup.dailyDue(last: nil, now: day(3), calendar: cal))
        XCTAssertFalse(Backup.dailyDue(last: day(3, 8), now: day(3, 20), calendar: cal))
        XCTAssertTrue(Backup.dailyDue(last: day(2, 23), now: day(3, 7), calendar: cal))
    }
}
