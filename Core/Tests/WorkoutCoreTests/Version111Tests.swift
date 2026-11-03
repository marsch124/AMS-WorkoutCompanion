import XCTest
@testable import WorkoutCore

/// Version 1.11: warm-ups, supersets, rest per type, finding machines and notes, records wall,
/// muscle balance, fixing a set afterwards.
final class Version111Tests: XCTestCase {
    let gym = UUID()
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        c.firstWeekday = 2
        return c
    }()

    private func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 10))! }

    private func log(_ machines: Machine...) -> GymLog {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        for m in machines { l.save(m) }
        return l
    }

    // MARK: Warm-ups

    func testWarmUpIsNeverARecordOrAReasonForMoreWeight() {
        let press = Machine(gymID: gym, name: "Press")
        var l = log(press)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: day(1), calendar: cal)
        // Day 2: a light warm-up with many reps, and a heavier warm-up than ever, then working sets.
        l.add(GymSet(kg: 60, reps: 3, warmup: true), machine: press.id, on: day(2), calendar: cal)
        l.add(GymSet(kg: 40, reps: 9), machine: press.id, on: day(2), calendar: cal)
        let v2 = l.visit(on: day(2), gym: gym, calendar: cal)!
        XCTAssertEqual(l.newBests(in: v2), [], "a warm-up heavier than ever is no New best")
        XCTAssertEqual(l.best(press.id), 40)
        XCTAssertEqual(l.top(press.id, in: v2), 40)
        XCTAssertEqual(v2.entries[0].heaviest, 40)
        XCTAssertEqual(Stats.records(l).first?.set.kg, 40)

        // Day 3: warm-up 20 × 5 (below 12), working sets all ≥ 12 → more weight is suggested.
        l.add(GymSet(kg: 20, reps: 5, warmup: true), machine: press.id, on: day(3), calendar: cal)
        l.add(GymSet(kg: 40, reps: 12), machine: press.id, on: day(3), calendar: cal)
        l.add(GymSet(kg: 40, reps: 12), machine: press.id, on: day(3), calendar: cal)
        let next = l.next(press.id, in: GymVisit(gymID: gym, date: day(4)))
        XCTAssertEqual(next.set.kg, 42.5, "the warm-up's 5 reps must not block the +2.5 kg tip")
        XCTAssertFalse(next.set.isWarmup)
    }

    func testWarmUpSurvivesTheFileAndOldSetsAreWorking() throws {
        let m = Machine(gymID: gym, name: "Row")
        var l = log(m)
        l.add(GymSet(kg: 10, reps: 10, warmup: true), machine: m.id, on: day(1), calendar: cal)
        l.add(GymSet(kg: 30, reps: 10), machine: m.id, on: day(1), calendar: cal)
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertEqual(back.visits[0].entries[0].sets.map(\.isWarmup), [true, false])
        let data = try GymFile.encode(l)
        XCTAssertEqual(String(decoding: data, as: UTF8.self).components(separatedBy: "\"warmup\"").count - 1, 1,
                       "only warm-ups carry the key")
    }

    // MARK: Supersets

    func testSupersetJumpsWithoutRestThenRestsAfterTheRound() {
        let a = Machine(gymID: gym, name: "Curl"), b = Machine(gymID: gym, name: "Pushdown")
        var l = log(a, b)
        l.pair(a.id, with: b.id)
        XCTAssertEqual(l.partner(of: a.id)?.id, b.id)
        XCTAssertEqual(l.partner(of: b.id)?.id, a.id)
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(1), calendar: cal)
        XCTAssertEqual(l.supersetJump(after: a.id, in: l.visit(on: day(1), gym: gym, calendar: cal)), b.id)
        l.add(GymSet(kg: 20, reps: 10), machine: b.id, on: day(1), calendar: cal)
        XCTAssertNil(l.supersetJump(after: b.id, in: l.visit(on: day(1), gym: gym, calendar: cal)), "round done: rest")
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(1), calendar: cal)
        XCTAssertEqual(l.supersetJump(after: a.id, in: l.visit(on: day(1), gym: gym, calendar: cal)), b.id)
    }

    func testPairingAnotherLetsTheOldPartnerGoAndDeletingClearsIt() throws {
        let a = Machine(gymID: gym, name: "A"), b = Machine(gymID: gym, name: "B"), c = Machine(gymID: gym, name: "C")
        var l = log(a, b, c)
        l.pair(a.id, with: b.id)
        l.pair(a.id, with: c.id)
        XCTAssertNil(l.partner(of: b.id))
        XCTAssertEqual(l.partner(of: c.id)?.id, a.id)
        l.delete(machine: c.id)
        XCTAssertNil(l.machine(a.id)?.partner)
        l.pair(a.id, with: b.id)
        l.pair(b.id, with: nil)
        XCTAssertNil(l.partner(of: a.id))
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertNil(back.machine(a.id)?.partner)
    }

    // MARK: Rest per type

    func testRestByTypeUnlessTheMachineHasItsOwn() throws {
        var heavy = Machine(gymID: gym, name: "Squat"); heavy.heavy = true
        let light = Machine(gymID: gym, name: "Fly")
        let push = Machine(gymID: gym, name: "Push-ups", logs: .reps)
        let own = Machine(gymID: gym, name: "Own", restSeconds: 45)
        var l = log(heavy, light, push, own)
        XCTAssertEqual([heavy, light, push, own].map { l.rest(for: $0) }, [120, 90, 60, 45])
        l.rests = RestDefaults(heavy: 180, light: 75, exercise: 30)
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertEqual([heavy, light, push, own].map { back.rest(for: $0) }, [180, 75, 30, 45])
        XCTAssertEqual(try GymFile.decode(Data(#"{"version":1,"machines":[],"visits":[]}"#.utf8)).rests, RestDefaults())
    }

    // MARK: Finding

    func testFindAMachineByNameOrSetting() {
        let l = log(Machine(gymID: gym, name: "Leg press", setting: "Seat 4"), Machine(gymID: gym, name: "Chest press"),
                    Machine(gymID: UUID(), name: "Leg curl elsewhere"))
        XCTAssertEqual(l.machines(in: gym, matching: "leg").map(\.name), ["Leg press"])
        XCTAssertEqual(l.machines(in: gym, matching: "seat").map(\.name), ["Leg press"])
        XCTAssertEqual(l.machines(in: gym, matching: " ").count, 2)
    }

    func testSearchMyNotesFindsMachineNotesVisitNotesAndSettings() {
        let m = Machine(gymID: gym, name: "Row", setting: "Chest pad 3")
        var l = log(m)
        l.add(GymSet(kg: 30, reps: 10), machine: m.id, on: day(1), calendar: cal)
        l.add(GymSet(kg: 30, reps: 10), machine: m.id, on: day(5), calendar: cal)
        let v1 = l.visit(on: day(1), gym: gym, calendar: cal)!.id
        let v5 = l.visit(on: day(5), gym: gym, calendar: cal)!.id
        l.nextTime(visit: v1, machine: m.id, set: GymSet(kg: 32.5, reps: 8), note: "Shoulder hurt a bit")
        l.describe(visit: v5, title: "Short one", notes: "Shoulder fine today")
        let hits = l.searchNotes("shoulder")
        XCTAssertEqual(hits.map(\.kind), [.visitNote, .machineNote], "newest first")
        XCTAssertEqual(hits[1].visitID, v1)
        XCTAssertTrue(hits[1].text.contains("Next time"))
        XCTAssertEqual(l.searchNotes("pad").map(\.kind), [.setting])
        XCTAssertEqual(l.searchNotes("  "), [])
    }

    // MARK: Records wall and muscle balance

    func testRecordsWallNewestRecordFirst() {
        let a = Machine(gymID: gym, name: "A"), b = Machine(gymID: gym, name: "B", logs: .reps)
        var l = log(a, b)
        l.add(GymSet(kg: 50, reps: 8), machine: a.id, on: day(1), calendar: cal)
        l.add(GymSet(kg: 0, reps: 20), machine: b.id, on: day(2), calendar: cal)
        l.add(GymSet(kg: 50, reps: 10), machine: a.id, on: day(3), calendar: cal) // same weight, more reps
        let r = Stats.records(l)
        XCTAssertEqual(r.map(\.machine.name), ["A", "B"])
        XCTAssertEqual(r[0].set.reps, 10)
        XCTAssertEqual(r[1].set.reps, 20)
    }

    func testMuscleBalanceShowsEveryGroupForFourWeeks() {
        var a = Machine(gymID: gym, name: "Press"); a.muscle = "chest"
        var l = log(a)
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(12), calendar: cal) // week of 12 Oct
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(30), calendar: cal) // week of 26 Oct
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(30), calendar: cal)
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: day(1), calendar: cal)   // too old
        let rows = Stats.muscleWeeks(l, weeks: 4, now: day(31), calendar: cal)
        XCTAssertEqual(rows.count, 7, "every group, also the empty ones")
        XCTAssertEqual(rows[0].muscle?.id, "chest")
        XCTAssertEqual(rows[0].weeks, [0, 1, 0, 2])
        XCTAssertEqual(rows[1].total, 0)
    }

    // MARK: Fixing a set afterwards

    func testFixASetInAnEarlierVisitByItsEntry() {
        let m = Machine(gymID: gym, name: "Row")
        var l = log(m)
        l.add(GymSet(kg: 30, reps: 10), machine: m.id, on: day(1), calendar: cal)
        l.add(GymSet(kg: 30, reps: 8), machine: m.id, on: day(1), calendar: cal)
        var v = l.visit(on: day(1), gym: gym, calendar: cal)!
        l.change(visit: v.id, entry: v.entries[0].id, set: 0, to: GymSet(kg: 32.5, reps: 10))
        v = l.visit(on: day(1), gym: gym, calendar: cal)!
        XCTAssertEqual(v.entries[0].sets.map(\.kg), [32.5, 30])
        l.change(visit: v.id, entry: v.entries[0].id, set: 1, to: nil)
        l.change(visit: v.id, entry: v.entries[0].id, set: 0, to: nil)
        XCTAssertNil(l.visit(on: day(1), gym: gym, calendar: cal), "an emptied visit goes")
    }
}
