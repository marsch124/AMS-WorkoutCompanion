import XCTest
@testable import WorkoutCore

/// 3.3: the planning board.
final class Version33BoardTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()
    func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 18))! }

    override func setUp() { GymSet.locale = Locale(identifier: "en_US") }

    private func setup() -> (GymLog, Machine, Machine, UUID) {
        var log = GymLog()
        log.ensureGym()
        let g = log.gyms[0].id
        let press = Machine(gymID: g, name: "Leg press")
        let fresh = Machine(gymID: g, name: "Rowing")
        log.save(press); log.save(fresh)
        log.add(GymSet(kg: 40, reps: 10), machine: press.id, on: day(2), calendar: cal)
        return (log, press, fresh, g)
    }

    func testStartingSetWriteKeepsTheNote() {
        var (log, press, _, _) = setup()
        let visit = log.visits[0].id
        log.nextTime(visit: visit, machine: press.id, set: nil, note: "Easy")
        XCTAssertTrue(log.setStartingSet(GymSet(kg: 45, reps: 8), machine: press.id))
        XCTAssertEqual(log.startingSet(press.id), GymSet(kg: 45, reps: 8))
        XCTAssertEqual(log.last(press.id)?.entry.note, "Easy")
        XCTAssertTrue(log.hasPlannedStart(press.id))
    }

    func testStartingSetOfAnUnusedMachine() {
        var (log, _, fresh, _) = setup()
        XCTAssertEqual(log.startingSet(fresh.id), GymLog.starter)
        XCTAssertFalse(log.setStartingSet(GymSet(kg: 30, reps: 10), machine: fresh.id))
        XCTAssertEqual(log.startingSet(fresh.id), GymLog.starter)
    }

    func testWarningNamesTheOtherDay() {
        var (log, press, _, g) = setup()
        XCTAssertNil(log.planDayWarning(for: day(10), gym: g, calendar: cal))
        log.setPlan([press.id], on: day(12), gym: g)
        XCTAssertEqual(log.planDayWarning(for: day(10), gym: g, calendar: cal), day(12))
        XCTAssertNil(log.planDayWarning(for: day(12), gym: g, calendar: cal))
    }

    func testAPlanForAFutureDayIsFoundOnThatDay() {
        var (log, press, _, g) = setup()
        log.setPlan([press.id], on: day(15), gym: g)
        XCTAssertEqual(log.plan(on: day(15), gym: g, calendar: cal)?.order, [press.id])
        XCTAssertNil(log.plan(on: day(14), gym: g, calendar: cal))
    }
}
