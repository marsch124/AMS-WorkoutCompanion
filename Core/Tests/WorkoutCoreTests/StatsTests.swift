import XCTest
@testable import WorkoutCore

/// 1.9: the statistics numbers.
final class StatsTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        c.firstWeekday = 2
        return c
    }()
    func day(_ d: Int, _ month: Int = 11, _ year: Int = 2026) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: d, hour: 18))!
    }
    // 2026-11-05 is a Thursday: the week is 2-8 Nov.
    var now: Date { day(5) }

    var chest = Machine(name: "Chest press")
    var legs = Machine(name: "Leg press")
    var tread = Machine(name: "Treadmill", logs: .time)
    var rower = Machine(name: "Rower", logs: .time)
    var pushups = Machine(name: "Push-ups", logs: .reps)

    override func setUp() {
        chest.muscle = .chest
    }

    func log(_ adds: [(Date, Machine, GymSet)]) -> GymLog {
        var g = GymLog(machines: [chest, legs, tread, rower, pushups])
        for (d, m, s) in adds { g.add(s, machine: m.id, on: d, now: d, calendar: cal) }
        return g
    }
    func items(_ g: GymLog, records: [SessionRecord] = []) -> [HistoryItem] { History.items(records: records, gym: g) }
    func record(_ d: Int, _ month: Int = 11, minutes: Int = 10) -> SessionRecord {
        SessionRecord(workoutID: nil, kind: .reps, name: "W", colour: "green", started: day(d, month),
                      ended: day(d, month).addingTimeInterval(Double(minutes) * 60), completed: true, detail: "x")
    }
    var week: DateInterval { History.period(.weekOfYear, around: now, calendar: cal) }
    var month: DateInterval { History.period(.month, around: now, calendar: cal) }

    func testWeekAndMonthBoundaries() {
        // Mon 2 Nov (week), Sun 1 Nov (month, not week), 31 Oct (neither).
        let g = log([(day(2), chest, GymSet(kg: 20, reps: 10)), (day(1), chest, GymSet(kg: 20, reps: 10)),
                     (day(31, 10), chest, GymSet(kg: 20, reps: 10))])
        let it = items(g)
        XCTAssertEqual(Stats.overview(it, gym: g, in: week).sessions, 1)
        XCTAssertEqual(Stats.overview(it, gym: g, in: month).sessions, 2)
    }

    func testOverviewCountsExercisesSetsAndKg() {
        let g = log([(day(3), chest, GymSet(kg: 20, reps: 10)), (day(3), chest, GymSet(kg: 20, reps: 10)),
                     (day(3), legs, GymSet(kg: 50, reps: 10))])
        let o = Stats.overview(items(g, records: [record(4, minutes: 15)]), gym: g, in: week)
        XCTAssertEqual(o.sessions, 2)
        XCTAssertEqual(o.exercises, 2)
        XCTAssertEqual(o.sets, 3)
        XCTAssertEqual(o.kg, 900)
        XCTAssertGreaterThanOrEqual(o.minutes, 15)
    }

    func testMusclesCountUntaggedAndTimeMachines() {
        let g = log([(day(3), chest, GymSet(kg: 20, reps: 10)), (day(3), chest, GymSet(kg: 20, reps: 10)),
                     (day(3), legs, GymSet(kg: 50, reps: 10)),
                     (day(3), tread, GymSet(seconds: 600, level: nil, incline: nil)),
                     (day(1), chest, GymSet(kg: 20, reps: 10))])
        let m = Stats.muscles(g, in: week)
        XCTAssertEqual(m, [MuscleCount(muscle: .chest, sets: 2), MuscleCount(muscle: .cardio, sets: 1),
                           MuscleCount(muscle: nil, sets: 1)])
        XCTAssertEqual(Stats.muscles(g, in: month).first, MuscleCount(muscle: .chest, sets: 3))
        XCTAssertEqual(Stats.muscles(GymLog(), in: week), [])
    }

    func testCardioMinutesPerMachine() {
        let g = log([(day(3), tread, GymSet(seconds: 30 * 60, level: nil, incline: nil)),
                     (day(3), tread, GymSet(seconds: 15 * 60, level: nil, incline: nil)),
                     (day(3), rower, GymSet(seconds: 20 * 60, level: nil, incline: nil)),
                     (day(3), chest, GymSet(kg: 20, reps: 10)),
                     (day(31, 10), rower, GymSet(seconds: 600, level: nil, incline: nil))])
        XCTAssertEqual(Stats.cardio(g, in: week), [CardioMinutes(name: "Treadmill", minutes: 45), CardioMinutes(name: "Rower", minutes: 20)])
    }

    func testBestStreakFindsTheLongestRun() {
        // Weeks of 12, 19, 26 Oct and 2 Nov in a row, a gap, then 14 Sep and 21 Sep.
        let it = items(GymLog(), records: [record(12, 10), record(19, 10), record(26, 10), record(2, 11), record(14, 9), record(21, 9)])
        XCTAssertEqual(Stats.bestStreak(it, calendar: cal), 4)
        XCTAssertEqual(History.weekStreak(it, now: now, calendar: cal), 4)
        XCTAssertEqual(Stats.bestStreak([], calendar: cal), 0)
    }

    func testPersonalRecordsThisMonthOnly() {
        var g = log([(day(20, 10), chest, GymSet(kg: 20, reps: 10)),   // first time: no record
                     (day(3), chest, GymSet(kg: 25, reps: 10)),        // record
                     (day(4), chest, GymSet(kg: 25, reps: 10)),        // same: no record
                     (day(3), legs, GymSet(kg: 50, reps: 10)),         // first time on legs
                     (day(4), legs, GymSet(kg: 60, reps: 10))])        // record
        XCTAssertEqual(Stats.personalRecords(g, in: month), 2)
        XCTAssertEqual(Stats.personalRecords(g, in: History.period(.month, around: day(20, 10), calendar: cal)), 0)
        g.add(GymSet(kg: 0, reps: 5), machine: pushups.id, on: day(2), now: day(2), calendar: cal)
        g.add(GymSet(kg: 0, reps: 8), machine: pushups.id, on: day(4), now: day(4), calendar: cal)
        XCTAssertEqual(Stats.personalRecords(g, in: month), 3)
    }

    func badge(_ id: String, _ g: GymLog, records: [SessionRecord] = []) -> Bool {
        Stats.badges(items(g, records: records), gym: g, calendar: cal).first { $0.id == id }!.earned
    }

    func testBadgeFirstAndSessionCounts() {
        XCTAssertFalse(badge("first", GymLog()))
        XCTAssertTrue(badge("first", GymLog(), records: [record(3)]))
        let nine = (1..<10).map { record($0, 10) }
        XCTAssertFalse(badge("sessions10", GymLog(), records: nine))
        XCTAssertTrue(badge("sessions10", GymLog(), records: nine + [record(3)]))
        let fifty = (0..<50).map { record(1 + $0 % 28, 1 + $0 / 28) }
        XCTAssertFalse(badge("sessions50", GymLog(), records: Array(fifty.dropLast())))
        XCTAssertTrue(badge("sessions50", GymLog(), records: fifty))
    }

    func testBadgeFourWeeksInARow() {
        XCTAssertFalse(badge("streak4", GymLog(), records: [record(12, 10), record(19, 10), record(26, 10)]))
        XCTAssertTrue(badge("streak4", GymLog(), records: [record(12, 10), record(19, 10), record(26, 10), record(3)]))
    }

    func testBadgeThousandKgInOneVisit() {
        let light = log([(day(3), chest, GymSet(kg: 50, reps: 10)), (day(3), chest, GymSet(kg: 49, reps: 10))])
        XCTAssertFalse(badge("kg1000", light))
        let heavy = log([(day(3), chest, GymSet(kg: 50, reps: 10)), (day(3), chest, GymSet(kg: 50, reps: 10))])
        XCTAssertTrue(badge("kg1000", heavy))
    }

    func testBadgeHundredRepsInAWeek() {
        let split = log([(day(3), pushups, GymSet(kg: 0, reps: 50)), (day(10), pushups, GymSet(kg: 0, reps: 50))])
        XCTAssertFalse(badge("pushups100", split))
        let one = log([(day(3), pushups, GymSet(kg: 0, reps: 50)), (day(5), pushups, GymSet(kg: 0, reps: 50))])
        XCTAssertTrue(badge("pushups100", one))
    }

    func testBadgeSixtyCardioMinutesInAWeek() {
        let short = log([(day(3), tread, GymSet(seconds: 30 * 60, level: nil, incline: nil)),
                         (day(10), tread, GymSet(seconds: 30 * 60, level: nil, incline: nil))])
        XCTAssertFalse(badge("cardio60", short))
        let full = log([(day(3), tread, GymSet(seconds: 40 * 60, level: nil, incline: nil)),
                        (day(4), rower, GymSet(seconds: 20 * 60, level: nil, incline: nil))])
        XCTAssertTrue(badge("cardio60", full))
    }
}
