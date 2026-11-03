import XCTest
@testable import WorkoutCore

/// 1.6: reps-only exercises (push-ups) and backups.
final class RepsAndBackupTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()
    func day(_ d: Int, _ hour: Int = 18) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    override func setUp() {
        GymSet.locale = Locale(identifier: "en_US")
    }

    let pushUps = Machine(name: "Push-ups", logs: .reps)

    func testANewRepsExerciseStartsAt10RepsWithoutWeight() {
        let log = GymLog(machines: [pushUps])
        let next = log.next(pushUps.id, in: GymVisit(date: day(3)))
        XCTAssertEqual(next.set, GymSet(kg: 0, reps: 10))
        XCTAssertNil(next.reason)
    }

    func testEverySetReachingTheFirstSetsRepsSuggestsOneMore() {
        var log = GymLog(machines: [pushUps])
        for r in [15, 15, 16] { log.add(GymSet(kg: 0, reps: r), machine: pushUps.id, on: day(2), calendar: cal) }
        let next = log.next(pushUps.id, in: GymVisit(date: day(4)))
        XCTAssertEqual(next.set, GymSet(kg: 0, reps: 16))
        XCTAssertEqual(next.reason, "Try 16 reps — every set last time reached 15")
    }

    func testAFallingSetKeepsLastTimesReps() {
        var log = GymLog(machines: [pushUps])
        for r in [15, 12] { log.add(GymSet(kg: 0, reps: r), machine: pushUps.id, on: day(2), calendar: cal) }
        XCTAssertEqual(log.next(pushUps.id, in: GymVisit(date: day(4))).set.reps, 15)
    }

    func testRepsExercisesSayRepsAndCountMostRepsAsBest() {
        var log = GymLog(machines: [pushUps])
        log.add(GymSet(kg: 0, reps: 15), machine: pushUps.id, on: day(2), calendar: cal)
        log.add(GymSet(kg: 0, reps: 18), machine: pushUps.id, on: day(4), calendar: cal)
        let entry = log.visits.first { cal.isDate($0.date, inSameDayAs: day(4)) }!.entries[0]
        XCTAssertEqual(log.text(entry), "18 reps")
        XCTAssertEqual(log.text(GymSet(kg: 0, reps: 12), machine: pushUps.id), "12 reps")
        XCTAssertEqual(log.best(pushUps.id), 18)
        let visit = log.visits.first { cal.isDate($0.date, inSameDayAs: day(4)) }!
        XCTAssertEqual(log.newBests(in: visit), [pushUps.id])
        XCTAssertEqual(log.history(pushUps.id).map(\.kg), [15, 18])
    }

    func testAVisitWithOnlyPushUpsShowsNoZeroKg() {
        var log = GymLog(machines: [pushUps])
        log.ensureGym()
        log.save(pushUps)
        log.add(GymSet(kg: 0, reps: 15), machine: log.machines[0].id, on: day(2), calendar: cal)
        let item = History.items(records: [], gym: log)[0]
        XCTAssertFalse(item.detail.contains("kg"), item.detail)
    }

    func testRepsKindSurvivesTheFile() throws {
        let log = GymLog(machines: [pushUps])
        XCTAssertEqual(try GymFile.decode(GymFile.encode(log)).machines[0].logs, .reps)
    }

    // MARK: Backups

    func testABackupReadsBackWithItsContentsAndPhotos() throws {
        var gym = GymLog(machines: [pushUps])
        gym.add(GymSet(kg: 0, reps: 15), machine: pushUps.id, on: day(2), calendar: cal)
        let files = ["workouts.json": try WorkoutFile.encode(Starters.all),
                     "gym.json": try GymFile.encode(gym),
                     "history.json": try HistoryFile.encode([]),
                     "other.txt": Data("not kept".utf8)]
        let photo = Data([0xFF, 0xD8, 0xFF, 0x01])
        let b = Backup(made: day(3), files: files, photos: ["a.jpg": photo])
        let back = try Backup.decode(Backup.encode(b))
        XCTAssertEqual(back, b)
        XCTAssertNil(back.files["other.txt"])
        XCTAssertEqual(back.photos["a.jpg"], photo)
        let c = try back.contents()
        XCTAssertEqual(c.workouts, Starters.all.count)
        XCTAssertEqual(c.machines, 1)
        XCTAssertEqual(c.visits, 1)
        XCTAssertEqual(c.photos, 1)
        XCTAssertTrue(c.text.hasSuffix("1 machine · 1 gym visit · 0 other sessions · 1 photo"), c.text)
    }

    func testAnythingElseIsNotABackup() {
        XCTAssertThrowsError(try Backup.decode(Data("{\"version\":1}".utf8)))
        XCTAssertThrowsError(try Backup.decode(Data("hello".utf8)))
    }

    func testADamagedFileInsideIsRefusedBeforeRestoring() {
        let b = Backup(made: day(3), files: ["gym.json": Data("{broken".utf8)], photos: [:])
        XCTAssertThrowsError(try b.contents())
    }

    func testWeeklyCopiesKeepTheNewestFour() {
        XCTAssertTrue(Backup.weeklyDue(newest: nil, now: day(10)))
        XCTAssertFalse(Backup.weeklyDue(newest: day(5), now: day(10)))
        XCTAssertTrue(Backup.weeklyDue(newest: day(3), now: day(10)))
        let made = (1...6).map { (name: "b\($0)", date: day($0)) }
        XCTAssertEqual(Set(Backup.toRemove(made)), ["b1", "b2"])
        XCTAssertEqual(Backup.fileName(day(3, 15), calendar: cal), "Workouts backup 2026-11-03 1500.json")
    }
}

/// 1.6: each gym keeps its own plan.
final class PlanPerGymTests: XCTestCase {
    func testPlanningASecondGymKeepsTheFirstGymsPlan() {
        let today = Date()
        var log = GymLog()
        log.ensureGym()
        let home = log.gyms[0].id
        let hotel = log.addGym("Hotel gym")
        let a = Machine(gymID: home, name: "Leg press"), b = Machine(gymID: hotel, name: "Rower"), c = Machine(gymID: hotel, name: "Squats")
        [a, b, c].forEach { log.save($0) }
        log.setPlan([a.id], on: today, gym: home)
        log.setPlan([c.id, b.id], on: today, gym: hotel)
        XCTAssertEqual(log.plan(on: today, gym: home)?.order, [a.id])
        XCTAssertEqual(log.plan(on: today, gym: hotel)?.order, [c.id, b.id])
        XCTAssertEqual(log.upNext(on: today, gym: hotel), c.id)
        log.later(c.id)
        XCTAssertEqual(log.plan(on: today, gym: hotel)?.order, [b.id, c.id])
        XCTAssertEqual(log.plan(on: today, gym: home)?.order, [a.id])
    }

    func testAnOldSinglePlanStillReads() throws {
        let gym = UUID(), m = UUID()
        let old = """
        {"version":1,"machines":[],"visits":[],"gyms":[{"id":"\(gym.uuidString)","name":"My gym"}],
         "plan":{"day":"2026-11-03T08:00:00Z","gymID":"\(gym.uuidString)","order":["\(m.uuidString)"],"skipped":[]}}
        """
        let log = try GymFile.decode(Data(old.utf8))
        XCTAssertEqual(log.plans.map(\.order), [[m]])
        XCTAssertEqual(try GymFile.decode(GymFile.encode(log)).plans.count, 1)
    }
}
