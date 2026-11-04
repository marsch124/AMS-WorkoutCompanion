import XCTest
@testable import WorkoutCore

/// Version 1.11.3: a visit's date with year and today/yesterday; a tile's "Last" follows the machine's kind.
final class Version113Tests: XCTestCase {
    let gym = UUID()
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()
    let en = Locale(identifier: "en_GB")

    private func day(_ d: Int, _ h: Int = 10) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    func testVisitDateHasTheYearAndSaysYesterdayOrToday() {
        XCTAssertEqual(GymVisit.dateText(day(3), now: day(4, 8), calendar: cal, locale: en), "Tuesday, 3 November 2026 · yesterday")
        XCTAssertEqual(GymVisit.dateText(day(4, 7), now: day(4, 20), calendar: cal, locale: en), "Wednesday, 4 November 2026 · today")
        XCTAssertEqual(GymVisit.dateText(day(1), now: day(4), calendar: cal, locale: en), "Sunday, 1 November 2026")
    }

    func testTimeMachineTileNeverShowsKilos() {
        var tread = Machine(gymID: gym, name: "Treadmill")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(tread)
        // Logged as a weight machine first, then switched to time.
        l.add(GymSet(kg: 20, reps: 10), machine: tread.id, on: day(1), calendar: cal)
        tread.logs = .time
        l.save(tread)
        XCTAssertEqual(l.lastText(tread), "New", "weight sets on a time machine are no 'Last: 20 kg'")
        l.add(GymSet(seconds: 25 * 60, level: 8, incline: 0), machine: tread.id, on: day(2), calendar: cal)
        l.add(GymSet(kg: 20, reps: 10), machine: tread.id, on: day(3), calendar: cal)
        XCTAssertEqual(l.lastText(tread), "Last: 25 min · level 8")
    }

    func testWeightMachineTileShowsTheHeaviestWorkingSet() {
        let press = Machine(gymID: gym, name: "Press")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(press)
        XCTAssertEqual(l.lastText(press), "New")
        l.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(1), calendar: cal)
        l.add(GymSet(kg: 35, reps: 8), machine: press.id, on: day(1), calendar: cal)
        XCTAssertTrue(l.lastText(press).hasPrefix("Last: 35"), l.lastText(press))
    }
}
