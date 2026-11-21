import XCTest
@testable import WorkoutCore

/// 2.0 warm-up: the clock starts with it, the visit survives with no sets, minutes and split include it,
/// Undo Finish clears the stretching.
final class Version20WarmupTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func at(_ min: Double) -> Date { t0.addingTimeInterval(min * 60) }

    func testStartWarmupStartsTheClockAndKeepsTheVisitWithNoSets() {
        var log = GymLog()
        log.ensureGym()
        let gym = log.currentGym?.id
        let id = log.startWarmup(kind: .cardio, gymID: gym, plannedMinutes: 8, at: t0)
        XCTAssertEqual(log.sessionStart(on: t0, gym: gym), t0)
        XCTAssertEqual(log.openVisit(on: t0, gym: gym)?.id, id)
        XCTAssertEqual(log.sessionClock(on: t0, gym: gym, now: at(30))?.seconds, 30 * 60, "a long warm-up is not idle")
        log.arrive(gym: gym, at: at(1))
        XCTAssertNil(log.arrived, "opening a machine does not restart the clock")
        log.endWarmup(visitID: id, at: at(8), speed: 9.5, heartRate: 128)
        let w = log.visits[0].warmup
        XCTAssertEqual(w?.minutes, 8)
        XCTAssertEqual(w?.speed, 9.5)
        XCTAssertEqual(w?.heartRate, 128)
        XCTAssertEqual(log.visits.count, 1)
        XCTAssertEqual(log.visits[0].setCount, 0, "a warm-up is never stored as sets")
    }

    func testMinutesAndSplitIncludeWarmupAndStretching() {
        var log = GymLog()
        log.ensureGym()
        let m = Machine(gymID: log.currentGym?.id, name: "Leg press")
        log.save(m)
        let gym = m.gymID
        let id = log.startWarmup(kind: .moves, gymID: gym, at: t0)
        log.endWarmup(visitID: id, at: at(8))
        log.add(GymSet(kg: 50, reps: 10), machine: m.id, on: t0, now: at(10))
        log.add(GymSet(kg: 50, reps: 10), machine: m.id, on: t0, now: at(40))
        log.finish(visit: id, at: at(41))
        var stretch = VisitPart(kind: .stretch, start: at(41))
        stretch.end = at(50)
        log.setStretching(visitID: id, part: stretch)
        let v = log.visits[0]
        XCTAssertEqual(v.minutes, 50)
        XCTAssertEqual(v.split.warmup, 8)
        XCTAssertEqual(v.split.stretch, 9)
        XCTAssertEqual(v.split.machines, 33)
    }

    func testUndoFinishAlsoClearsStretching() {
        var log = GymLog()
        log.ensureGym()
        let m = Machine(gymID: log.currentGym?.id, name: "Leg press")
        log.save(m)
        log.add(GymSet(kg: 50, reps: 10), machine: m.id, on: t0, now: t0)
        let id = log.visits[0].id
        let before = log
        log.finish(visit: id, at: at(20))
        log.setStretching(visitID: id, part: VisitPart(kind: .stretch, start: at(20), end: at(28)))
        log.undoFinish(visit: id, before: before)
        XCTAssertNil(log.visits[0].stretching)
        XCTAssertNil(log.visits[0].finished)
    }
}
