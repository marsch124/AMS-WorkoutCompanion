import XCTest
@testable import WorkoutCore

/// Version 1.23: effort, pain, holds, move to the next visit, the clock that pauses, how it felt,
/// today against last visit, the lock-screen card, the gym reminder, opening hours, the stretch.
final class Version123Tests: XCTestCase {
    let gym = UUID()
    let press = Machine(name: "Press")
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    /// 2026-10-<d> at hh:mm (14 Oct 2026 is a Wednesday).
    private func at(_ d: Int, _ h: Int = 10, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h, minute: m))!
    }

    private func log(_ machines: Machine...) -> GymLog {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        for var m in machines { m.gymID = gym; l.save(m) }
        return l
    }

    private func pressLog() -> (GymLog, UUID) {
        var m = press
        m.gymID = gym
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(m)
        return (l, m.id)
    }

    // 1
    func testLastSetAndLine() {
        let (l0, id) = pressLog()
        var l = l0
        l.add(GymSet(kg: 20, reps: 5, warmup: true), machine: id, on: at(1), now: at(1), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 10, 5), calendar: cal)
        l.add(GymSet(kg: 40, reps: 8), machine: id, on: at(1), now: at(1, 10, 10), calendar: cal)
        let v1 = l.visit(on: at(1), gym: gym, calendar: cal)!
        l.effort(visit: v1.id, machine: id, set: 1, .hard)
        XCTAssertEqual(l.lastSet(id, place: 0, excluding: nil)?.reps, 10, "warm-up not counted")
        XCTAssertEqual(l.lastSet(id, place: 1, excluding: nil)?.reps, 8)
        XCTAssertEqual(l.lastSetLine(id, place: 0, excluding: nil), "Last time: 40 kg × 10 · hard")
        XCTAssertEqual(l.lastSetLine(id, place: 1, excluding: nil), "Last time: 40 kg × 8")
        XCTAssertNil(l.lastSet(id, place: 2, excluding: nil), "beyond last time's sets")
        XCTAssertNil(l.lastSet(id, place: 0, excluding: v1.id), "no earlier visit")
        var t = Machine(name: "Bike", logs: .time)
        t.gymID = gym
        l.save(t)
        l.add(GymSet(seconds: 600, level: 5, incline: nil), machine: t.id, on: at(1), now: at(1, 10, 20), calendar: cal)
        XCTAssertNil(l.lastSet(t.id, place: 0, excluding: nil), "time machine")
    }

    // 2
    func testEffortSetsClearsAndNeverCarries() {
        let (l0, id) = pressLog()
        var l = l0
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1), calendar: cal)
        let v = l.visit(on: at(1), gym: gym, calendar: cal)!
        l.effort(visit: v.id, machine: id, set: 0, .hard)
        XCTAssertEqual(l.visits[0].entries[0].sets[0].effort, .hard)
        XCTAssertNil(l.next(id, in: l.visits[0]).set.effort, "same visit")
        XCTAssertNil(l.next(id, in: GymVisit(gymID: gym, date: at(2))).set.effort, "next visit")
        l.effort(visit: v.id, machine: id, set: 0, .hard)
        XCTAssertNil(l.visits[0].entries[0].sets[0].effort, "same choice again clears")
    }

    // 3
    func testHoldAndSecondsText() {
        XCTAssertTrue(Machine(name: "Plank", logs: .time, hasLevel: false, hasIncline: false).isHold)
        XCTAssertFalse(Machine(name: "Bike", logs: .time, hasLevel: true, hasIncline: false).isHold)
        XCTAssertFalse(Machine(name: "Mill", logs: .time, hasLevel: false, hasIncline: true).isHold)
        XCTAssertFalse(Machine(name: "Press", logs: .weights, hasLevel: false, hasIncline: false).isHold)
        XCTAssertEqual(GymSet(seconds: 45, level: nil, incline: nil).text, "45 s")
        XCTAssertEqual(GymSet(seconds: 90, level: nil, incline: nil).text, "1:30 min")
    }

    // 4
    func testPainKeepsTheSameSet() {
        let (l0, id) = pressLog()
        var l = l0
        for i in 0..<3 { l.add(GymSet(kg: 40, reps: 12), machine: id, on: at(1), now: at(1, 10, i), calendar: cal) }
        let v = l.visit(on: at(1), gym: gym, calendar: cal)!
        l.pain(visit: v.id, machine: id, true)
        XCTAssertTrue(l.painLastTime(id, excluding: nil))
        let n = l.next(id, in: GymVisit(gymID: gym, date: at(2)))
        XCTAssertEqual(n.set.kg, 40)
        XCTAssertEqual(n.set.reps, 12)
        XCTAssertTrue(n.reason?.hasPrefix("Pain last time") == true)
        l.pain(visit: v.id, machine: id, false)
        XCTAssertNil(l.visits[0].entries[0].pain)
        let more = l.next(id, in: GymVisit(gymID: gym, date: at(2)))
        XCTAssertEqual(more.set.kg, 42.5, "without pain every set at the top gives more weight")
    }

    // 5
    func testMoveToNextVisit() {
        let a = Machine(name: "A"), b = Machine(name: "B")
        var l = log(a, b)
        l.setPlan([a.id, b.id], on: at(1), gym: gym)
        l.moveToNextVisit(a.id, on: at(1))
        XCTAssertTrue(l.plans[0].skipped.contains(a.id), "skipped today")
        XCTAssertTrue(l.isCarried(a.id))
        XCTAssertTrue(l.carriedOver(gym: gym, on: at(1, 18), calendar: cal).isEmpty, "same day")
        XCTAssertEqual(l.carriedOver(gym: gym, on: at(2), calendar: cal).map(\.id), [a.id])
        XCTAssertTrue(l.carriedOver(gym: UUID(), on: at(2), calendar: cal).isEmpty, "other gym")
        // setPlan uses .current calendar: pick a time well inside the day so every zone agrees.
        l.setPlan([b.id], on: at(3), gym: gym)
        XCTAssertEqual(l.plans[0].order, [a.id, b.id], "carried machine goes first")
        l.add(GymSet(kg: 10, reps: 10), machine: a.id, on: at(3), now: at(3), calendar: cal)
        XCTAssertFalse(l.isCarried(a.id), "a set removes it")
        l.moveToNextVisit(b.id, on: at(3))
        l.dropCarry(b.id)
        XCTAssertTrue(l.carried.isEmpty)
    }

    // 6
    func testActiveClockCapsGaps() {
        let t0 = at(1)
        func s(_ min: Int, seconds: Int? = nil) -> GymSet {
            var g = seconds.map { GymSet(seconds: $0, level: nil, incline: nil) } ?? GymSet(kg: 1, reps: 1)
            g.at = t0.addingTimeInterval(Double(min) * 60)
            return g
        }
        var r = GymVisit.active(start: t0, sets: [s(5), s(15)], now: t0.addingTimeInterval(16 * 60))
        XCTAssertEqual(r.seconds, 16 * 60)
        XCTAssertFalse(r.paused)
        r = GymVisit.active(start: t0, sets: [s(5), s(55)], now: t0.addingTimeInterval(56 * 60))
        XCTAssertEqual(r.seconds, (5 + 20 + 1) * 60, "50-min gap counts 20")
        r = GymVisit.active(start: t0, sets: [s(45, seconds: 1800)], now: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(r.seconds, 45 * 60, "time set: gap fully counted up to limit + its own length")
        r = GymVisit.active(start: t0, sets: [s(5)], now: t0.addingTimeInterval(5 * 60 + 19 * 60))
        XCTAssertFalse(r.paused)
        r = GymVisit.active(start: t0, sets: [s(5)], now: t0.addingTimeInterval(5 * 60 + 21 * 60))
        XCTAssertTrue(r.paused)
        XCTAssertEqual(r.seconds, 25 * 60)
    }

    // 7
    func testFeelAndNewFieldsRoundTrip() throws {
        let (l0, id) = pressLog()
        var l = l0
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1), calendar: cal)
        let v = l.visit(on: at(1), gym: gym, calendar: cal)!
        l.feel(visit: v.id, .tired)
        l.effort(visit: v.id, machine: id, set: 0, .easy)
        l.pain(visit: v.id, machine: id, true)
        let hours: [DayHours?] = [DayHours(open: 360, close: 1320), nil, nil, nil, nil, nil, nil]
        l.setHours(gym, hours)
        l.carried = [Carry(machineID: id, day: at(1))]
        l.nudgeDays = 7
        let stretch = UUID()
        l.stretchID = stretch
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertEqual(back.visits[0].feel, .tired)
        XCTAssertEqual(back.visits[0].entries[0].sets[0].effort, .easy)
        XCTAssertEqual(back.visits[0].entries[0].pain, true)
        XCTAssertEqual(back.gyms[0].hours, hours)
        XCTAssertEqual(back.carried, l.carried)
        XCTAssertEqual(back.nudgeDays, 7)
        XCTAssertEqual(back.stretchID, stretch)
    }

    func testOldFileDecodesWithDefaults() throws {
        let (l, _) = pressLog()
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertTrue(back.carried.isEmpty)
        XCTAssertNil(back.stretchID)
        XCTAssertEqual(back.nudgeAfter, 4)
        XCTAssertNil(back.gyms[0].hours)
    }

    // 8
    func testCompareAgainstEarlierVisit() {
        let (l0, id) = pressLog()
        var l = l0
        var other = Machine(name: "Other")
        other.gymID = gym
        l.save(other)
        // Day 1: one machine, 2 sets, 30 min.  Day 2: two machines, 4 sets, 24 min.
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 10, 0), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 10, 30), calendar: cal)
        for (i, m) in [(0, id), (8, id), (16, other.id), (24, other.id)] {
            l.add(GymSet(kg: 40, reps: 10), machine: m, on: at(2), now: at(2, 10, i), calendar: cal)
        }
        let v1 = l.visit(on: at(1), gym: gym, calendar: cal)!
        let v2 = l.visit(on: at(2), gym: gym, calendar: cal)!
        XCTAssertTrue(l.compare(v1).isEmpty, "first visit")
        let lines = l.compare(v2)
        let sets = lines.first { $0.id == "sets" }!
        XCTAssertEqual(sets.change, "+2")
        XCTAssertEqual(sets.better, true)
        XCTAssertEqual(lines.first { $0.id == "machines" }!.change, "+1")
        let time = lines.first { $0.id == "time" }!
        XCTAssertEqual(time.change, "−6 min")
        XCTAssertNil(time.better)
        // Day 3: back to 2 sets (fewer), then day 4 the same.
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(3), now: at(3), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(3), now: at(3, 10, 5), calendar: cal)
        let down = l.compare(l.visit(on: at(3), gym: gym, calendar: cal)!).first { $0.id == "sets" }!
        XCTAssertEqual(down.change, "−2")
        XCTAssertEqual(down.better, false)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(4), now: at(4), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(4), now: at(4, 10, 5), calendar: cal)
        let same = l.compare(l.visit(on: at(4), gym: gym, calendar: cal)!).first { $0.id == "sets" }!
        XCTAssertEqual(same.change, "same")
        XCTAssertNil(same.better)
        // Another gym: not compared.
        let g2 = l.addGym("Second")
        var m2 = Machine(name: "Row")
        m2.gymID = g2
        l.save(m2)
        l.add(GymSet(kg: 30, reps: 10), machine: m2.id, on: at(5), now: at(5), calendar: cal)
        XCTAssertTrue(l.compare(l.visit(on: at(5), gym: g2, calendar: cal)!).isEmpty)
    }

    // 9
    func testSessionCard() {
        let (l0, id) = pressLog()
        var l = l0
        XCTAssertNil(l.sessionCard(on: at(1), gym: gym, now: at(1), calendar: cal))
        l.arrive(gym: gym, at: at(1, 10, 0), calendar: cal)
        let none = l.sessionCard(on: at(1), gym: gym, now: at(1, 10, 5), calendar: cal)!
        XCTAssertEqual(none.line, "No sets yet")
        XCTAssertEqual(none.gym, "G")
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 10, 2), calendar: cal)
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 10, 4), calendar: cal)
        let now = at(1, 10, 5)
        let card = l.sessionCard(on: at(1), gym: gym, now: now, calendar: cal)!
        XCTAssertEqual(card.line, "1 machine · 2 sets")
        XCTAssertEqual(card.machine, "Press")
        XCTAssertEqual(card.seconds, 300)
        XCTAssertEqual(card.start, now.addingTimeInterval(-300))
        XCTAssertFalse(card.paused)
    }

    // 10
    func testNudgeDate() {
        let (l0, id) = pressLog()
        var l = l0
        XCTAssertNil(l.nudgeDate(now: at(1), calendar: cal), "no visit")
        l.add(GymSet(kg: 40, reps: 10), machine: id, on: at(1), now: at(1, 9), calendar: cal)
        XCTAssertEqual(l.nudgeDate(now: at(1, 12), calendar: cal), at(5, 10))
        XCTAssertNil(l.nudgeDate(now: at(6), calendar: cal), "time passed")
        l.nudgeDays = 7
        XCTAssertEqual(l.nudgeDate(now: at(1, 12), calendar: cal), at(8, 10))
        l.nudgeDays = 0
        XCTAssertNil(l.nudgeDate(now: at(1, 12), calendar: cal), "switched off")
    }

    // 11
    func testOpeningLine() {
        var g = GymPlace(name: "G")
        XCTAssertNil(g.openLine(at: at(14), calendar: cal))
        let day = DayHours(open: 360, close: 1320)
        g.hours = Array(repeating: day, count: 7)
        XCTAssertEqual(g.openLine(at: at(14, 12), calendar: cal)?.text, "Open · closes 22:00")
        XCTAssertEqual(g.openLine(at: at(14, 12), calendar: cal)?.open, true)
        XCTAssertEqual(g.openLine(at: at(14, 21, 20), calendar: cal)?.text, "Closes in 40 min")
        XCTAssertEqual(g.openLine(at: at(14, 5), calendar: cal)?.text, "Closed · opens 06:00")
        XCTAssertEqual(g.openLine(at: at(14, 22, 30), calendar: cal)?.text, "Closed · opens tomorrow 06:00")
        XCTAssertEqual(g.openLine(at: at(14, 22, 30), calendar: cal)?.open, false)
        g.hours![3] = nil   // Thursday closed; 14 Oct is a Wednesday
        XCTAssertEqual(g.openLine(at: at(14, 22, 30), calendar: cal)?.text, "Closed · opens Friday 06:00")
        var l = GymLog(gyms: [g])
        l.setHours(g.id, [DayHours?](repeating: nil, count: 7))
        XCTAssertNil(l.gyms[0].hours)
    }

    // 12
    func testAfterGymStretch() {
        let w = Workout.afterGymStretch()
        XCTAssertEqual(w.kind, .checklist)
        XCTAssertEqual(w.exercises.count, 6)
    }
}
