import XCTest
@testable import WorkoutCore

/// 1.4: gyms, today's plan, a visit's heading and notes, and History.
final class GymPlanHistoryTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        c.firstWeekday = 2
        return c
    }()
    func day(_ d: Int, _ hour: Int = 18) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    override func setUp() { GymSet.locale = Locale(identifier: "en_US") }

    // MARK: Gyms

    func testAFileFromBeforeGymsPutsEverythingInMyGym() throws {
        let press = Machine(name: "Chest press")
        var old = GymLog(machines: [press])
        old.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(2), calendar: cal)
        let back = try GymFile.decode(GymFile.encode(old))
        XCTAssertEqual(back.gyms.map(\.name), ["My gym"])
        let gym = back.gyms[0].id
        XCTAssertEqual(back.currentGym?.id, gym)
        XCTAssertEqual(back.machines(in: gym).map(\.name), ["Chest press"])
        XCTAssertEqual(back.visits(in: gym).count, 1)
    }

    func testEachGymHasItsOwnMachinesAndVisits() {
        var log = GymLog()
        log.ensureGym()
        let city = log.gyms[0].id
        let hotel = log.addGym("  Hotel gym ")
        XCTAssertEqual(log.currentGym?.name, "Hotel gym")
        let press = Machine(gymID: city, name: "Chest press")
        let bench = Machine(gymID: hotel, name: "Bench")
        log.save(press); log.save(bench)
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(3), calendar: cal)
        log.add(GymSet(kg: 20, reps: 10), machine: bench.id, on: day(3, 19), calendar: cal)
        XCTAssertEqual(log.machines(in: hotel).map(\.name), ["Bench"])
        // Same day, two gyms: two visits.
        XCTAssertEqual(log.visit(on: day(3), gym: city, calendar: cal)?.setCount, 1)
        XCTAssertEqual(log.visit(on: day(3), gym: hotel, calendar: cal)?.setCount, 1)
        log.renameGym(city, to: "City gym")
        XCTAssertEqual(log.gyms[0].name, "City gym")
        log.renameGym(city, to: "   ")
        XCTAssertEqual(log.gyms[0].name, "City gym")
    }

    // MARK: Plan

    func testUpNextIsTheFirstPlannedMachineNotDoneSkippedOrBusy() {
        let a = Machine(name: "A"), b = Machine(name: "B"), c = Machine(name: "C")
        var log = GymLog(machines: [a, b, c])
        log.setPlan([a.id, b.id, c.id], on: day(3), gym: nil)
        XCTAssertEqual(log.upNext(on: day(3), gym: nil, calendar: cal), a.id)
        log.add(GymSet(kg: 30, reps: 10), machine: a.id, on: day(3), calendar: cal)
        XCTAssertEqual(log.upNext(on: day(3), gym: nil, calendar: cal), b.id)
        log.setBusy(b.id, true, on: day(3), calendar: cal)
        XCTAssertEqual(log.upNext(on: day(3), gym: nil, calendar: cal), c.id)
        log.skip(c.id)
        XCTAssertNil(log.upNext(on: day(3), gym: nil, calendar: cal))
        log.skip(c.id, false)
        XCTAssertEqual(log.upNext(on: day(3), gym: nil, excluding: c.id, calendar: cal), nil)
        // Another day has no plan.
        XCTAssertNil(log.plan(on: day(4), gym: nil, calendar: cal))
    }

    func testLaterSwapAndRemoveChangeThePlan() {
        let a = Machine(name: "A"), b = Machine(name: "B"), c = Machine(name: "C"), d = Machine(name: "D")
        var log = GymLog(machines: [a, b, c, d])
        log.setPlan([a.id, b.id, c.id], on: day(3), gym: nil)
        log.later(a.id)
        XCTAssertEqual(log.plans.first?.order, [b.id, c.id, a.id])
        log.swap(c.id, for: d.id)
        XCTAssertEqual(log.plans.first?.order, [b.id, d.id, a.id])
        log.swap(b.id, for: a.id) // already planned: nothing happens
        XCTAssertEqual(log.plans.first?.order, [b.id, d.id, a.id])
        log.removeFromPlan(d.id)
        XCTAssertEqual(log.plans.first?.order, [b.id, a.id])
        log.delete(machine: b.id)
        XCTAssertEqual(log.plans.first?.order, [a.id])
        log.removeFromPlan(a.id)
        XCTAssertTrue(log.plans.isEmpty)
    }

    func testFinishEndsTodaysPlanAndKeepsTheHeadingAndNotes() throws {
        let a = Machine(name: "A")
        var log = GymLog(machines: [a])
        log.setPlan([a.id], on: day(3), gym: nil)
        log.add(GymSet(kg: 30, reps: 10), machine: a.id, on: day(3), now: day(3, 18), calendar: cal)
        let v = log.visits[0].id
        log.finish(visit: v, at: day(3, 18).addingTimeInterval(5 * 60), calendar: cal)
        XCTAssertTrue(log.plans.isEmpty)
        XCTAssertEqual(log.visits[0].minutes, 5)
        log.describe(visit: v, title: " Leg day ", notes: "Knee felt fine.")
        log.describe(visit: v, title: " Leg day ", notes: "Knee felt fine.")
        XCTAssertEqual(log.visits[0].title, "Leg day")
        XCTAssertEqual(log.visits[0].notes, "Knee felt fine.")
        let back = try GymFile.decode(GymFile.encode(log))
        XCTAssertEqual(back.visits[0].title, "Leg day")
        log.describe(visit: v, title: "", notes: "  ")
        XCTAssertNil(log.visits[0].title)
        XCTAssertNil(log.visits[0].notes)
    }

    // MARK: History

    func pushups() -> Workout { Workout(name: "Push-ups", kind: .reps, colour: "orange") }

    func testARecordSaysHowFarTheWorkoutGot() {
        var w = pushups()
        w.sets = 5; w.reps = 20
        let phases = Plan.phases(for: w)
        let full = SessionRecord.of(w, started: day(3, 7), ended: day(3, 8), phasesDone: phases, finished: true)
        XCTAssertEqual(full?.detail, "5 of 5 sets × 20 reps")
        XCTAssertEqual(full?.completed, true)
        let part = SessionRecord.of(w, started: day(3, 7), ended: day(3, 8), phasesDone: Array(phases.prefix(3)), finished: false)
        XCTAssertEqual(part?.detail, "2 of 5 sets × 20 reps")
        // Ended before the first set: nothing to keep.
        XCTAssertNil(SessionRecord.of(w, started: day(3, 7), ended: day(3, 7), phasesDone: [], finished: false))
        var list = Workout(name: "Doctor", kind: .checklist, colour: "pink")
        list.exercises = [Exercise(name: "a"), Exercise(name: "b")]
        XCTAssertEqual(SessionRecord.of(list, started: day(3), ended: day(3), ticked: 1)?.detail, "1 of 2 exercises")
        XCTAssertNil(SessionRecord.of(list, started: day(3), ended: day(3), ticked: 0))
    }

    func testHistoryMixesGymAndWorkoutsNewestFirstWithTotals() throws {
        let a = Machine(name: "A")
        var log = GymLog(machines: [a])
        log.ensureGym()
        log.machines[0].gymID = log.gyms[0].id
        log.add(GymSet(kg: 30, reps: 10), machine: a.id, on: day(2), now: day(2, 18), calendar: cal)
        log.finish(visit: log.visits[0].id, at: day(2, 18).addingTimeInterval(5 * 60), calendar: cal)
        let rec = SessionRecord(workoutID: nil, kind: .reps, name: "Push-ups", colour: "orange",
                                started: day(3, 7), ended: day(3, 7).addingTimeInterval(600), completed: false, detail: "2 of 5 sets × 20 reps")
        let items = History.items(records: [rec], gym: log)
        XCTAssertEqual(items.map(\.name), ["Push-ups", "At the gym · My gym"])
        XCTAssertEqual(items[0].detail, "2 of 5 sets × 20 reps · ended early")
        XCTAssertEqual(items[1].detail, "1 machine · 1 set · 300 kg")
        let week = History.period(.weekOfYear, around: day(4), calendar: cal)
        XCTAssertEqual(History.totals(items, in: week), HistoryTotals(sessions: 2, minutes: 15, kg: 300))
        XCTAssertEqual(try HistoryFile.decode(HistoryFile.encode([rec])), [rec])
    }

    func testWeeksInARow() {
        func item(_ d: Date) -> HistoryItem {
            HistoryItem(source: .workout(UUID()), date: d, name: "x", colour: "orange", group: "x",
                        detail: "", minutes: 10, kg: 0, completed: true)
        }
        // 3 Nov 2026 is a Tuesday. Sessions this week, last week and the week before; a gap before that.
        let oct = { (d: Int) in self.cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 18))! }
        let list = [item(day(3)), item(oct(28)), item(oct(21)), item(oct(7))]
        XCTAssertEqual(History.weekStreak(list, now: day(3), calendar: cal), 3)
        // Nothing yet this week still counts the weeks before.
        XCTAssertEqual(History.weekStreak(Array(list.dropFirst()), now: day(3), calendar: cal), 2)
        XCTAssertEqual(History.weekStreak([], now: day(3), calendar: cal), 0)
        let bars = History.weekly(list, weeks: 4, now: day(3), calendar: cal)
        XCTAssertEqual(bars.map(\.sessions), [0, 1, 1, 1])
    }

    // MARK: Time machines, next time, instructions

    func testATimeMachineLogsTimeLevelAndIncline() throws {
        let tread = Machine(name: "Treadmill", logs: .time)
        var log = GymLog(machines: [tread])
        // A new time machine starts at 20 minutes, level 5, no incline.
        XCTAssertEqual(log.next(tread.id, in: GymVisit(date: day(3))).set, GymSet.starterTime)
        let run = GymSet(seconds: 25 * 60, level: 8, incline: 2.5)
        log.add(run, machine: tread.id, on: day(3), calendar: cal)
        XCTAssertEqual(run.text, "25 min · level 8 · incline 2.5 %")
        XCTAssertEqual(GymSet(seconds: 90, level: nil, incline: nil).text, "1:30 min")
        XCTAssertEqual(log.visits[0].entries[0].text, "25 min · level 8 · incline 2.5 %")
        // Time is no weight: no kilograms, no "new best".
        XCTAssertEqual(log.visits[0].totalKg, 0)
        XCTAssertNil(log.best(tread.id))
        XCTAssertEqual(log.visits[0].minutesOnMachines, 25)
        // Next time starts from last time's numbers.
        XCTAssertEqual(log.next(tread.id, in: GymVisit(date: day(5))).set, run)
        let back = try GymFile.decode(GymFile.encode(log))
        XCTAssertEqual(back.machines[0].logs, .time)
        XCTAssertEqual(back.visits[0].entries[0].sets, [run])
    }

    func testAnOldMachineLogsWeights() throws {
        let old = Data(#"{"version":1,"machines":[{"id":"6A1D2E9C-1111-4C3B-9A51-0D5C7D2B9E01","name":"Row","setting":""}],"visits":[]}"#.utf8)
        XCTAssertEqual(try GymFile.decode(old).machines[0].logs, .weights)
    }

    func testThePlanForNextTimeAndTheNoteShowNextTime() {
        let row = Machine(name: "Seated row")
        var log = GymLog(machines: [row])
        log.add(GymSet(kg: 39, reps: 20), machine: row.id, on: day(3), calendar: cal)
        let v = log.visits[0].id
        log.nextTime(visit: v, machine: row.id, set: GymSet(kg: 45, reps: 15), note: " Easy, go up. ")
        let entry = log.visits[0].entries[0]
        XCTAssertEqual(entry.nextTime, GymSet(kg: 45, reps: 15))
        XCTAssertEqual(entry.note, "Easy, go up.")
        let next = log.next(row.id, in: GymVisit(date: day(6)))
        XCTAssertEqual(next.set, GymSet(kg: 45, reps: 15))
        XCTAssertEqual(next.reason, "Your plan from last time: 45 kg × 15")
        XCTAssertEqual(log.last(row.id)?.entry.note, "Easy, go up.")
        // Clearing both takes them away.
        log.nextTime(visit: v, machine: row.id, set: nil, note: "")
        XCTAssertNil(log.visits[0].entries[0].nextTime)
        XCTAssertNil(log.visits[0].entries[0].note)
    }

    func testTheInstructionsPhotoIsKept() {
        let log = GymLog(machines: [Machine(name: "Row", photo: "m.jpg", instructions: "i.jpg")])
        XCTAssertEqual(log.photosInUse, ["m.jpg", "i.jpg"])
    }

    // MARK: 1.5 — rest, weight step and the reps rule per machine

    func testAMachineWithoutSettingsKeepsTheOldRules() {
        let m = Machine(name: "Row")
        XCTAssertEqual(m.rest, 90)
        XCTAssertEqual(m.weightStep, 2.5)
        XCTAssertEqual(m.repsForMore, 12)
    }

    func testAFiveKiloMachineSuggestsFiveMoreAtItsOwnReps() throws {
        let leg = Machine(name: "Leg press", restSeconds: 150, step: 5, topReps: 10)
        var log = GymLog(machines: [leg])
        for _ in 0..<3 { log.add(GymSet(kg: 40, reps: 10), machine: leg.id, on: day(1), calendar: cal) }
        let next = log.next(leg.id, in: GymVisit(date: day(3)))
        XCTAssertEqual(next.set, GymSet(kg: 45, reps: 8))
        XCTAssertEqual(next.reason, "Try 45 kg — every set last time reached 10 reps")
        let back = try GymFile.decode(GymFile.encode(log)).machines[0]
        XCTAssertEqual(back.rest, 150)
        XCTAssertEqual(back.weightStep, 5)
        XCTAssertEqual(back.repsForMore, 10)
    }

    func testNineRepsOnATenRepMachineIsNoSuggestion() {
        let leg = Machine(name: "Leg press", step: 5, topReps: 10)
        var log = GymLog(machines: [leg])
        log.add(GymSet(kg: 40, reps: 9), machine: leg.id, on: day(1), calendar: cal)
        XCTAssertNil(log.next(leg.id, in: GymVisit(date: day(3))).reason)
    }

    func testATreadmillWithoutALevelLogsTimeAndInclineOnly() throws {
        let tread = Machine(name: "Treadmill", logs: .time, hasLevel: false)
        XCTAssertFalse(tread.hasLevel)
        XCTAssertTrue(tread.hasIncline)
        var log = GymLog(machines: [tread])
        XCTAssertEqual(log.next(tread.id, in: GymVisit(date: day(3))).set, GymSet(seconds: 1200, level: nil, incline: 0))
        let run = GymSet(seconds: 1500, level: nil, incline: 3)
        XCTAssertEqual(run.text, "25 min · incline 3 %")
        log.add(run, machine: tread.id, on: day(3), calendar: cal)
        XCTAssertEqual(try GymFile.decode(GymFile.encode(log)).machines[0].hasLevel, false)
        // A bike: a level, no incline.
        let bike = Machine(name: "Bike", logs: .time, hasIncline: false)
        XCTAssertEqual(GymLog(machines: [bike]).next(bike.id, in: GymVisit(date: day(3))).set, GymSet(seconds: 1200, level: 5, incline: nil))
    }
}
