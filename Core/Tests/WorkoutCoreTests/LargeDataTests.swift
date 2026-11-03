import XCTest
@testable import WorkoutCore

/// Made-up, large data: two years of gym visits, 300 other sessions, 30 workouts, 200 fake photos.
/// The time limits are generous so a slow CI machine still passes; a failure means something got badly slow.
final class LargeDataTests: XCTestCase {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()
    static let now = Date(timeIntervalSince1970: 1_793_000_000)

    struct Big {
        var log: GymLog
        var records: [SessionRecord]
        var workouts: [Workout]
        var photos: [String: Data]
    }

    static func make() -> Big {
        let gymA = GymPlace(name: "Gym A")
        let gymB = GymPlace(name: "Gym B")
        var machines: [Machine] = []
        for g in [gymA, gymB] {
            for m in 0..<8 {
                machines.append(Machine(gymID: g.id, name: "Machine \(m) \(g.name)"))
            }
        }
        var visits: [GymVisit] = []
        let weeks = 104
        for w in 0..<weeks {
            for d in 0..<3 {
                let day = Double(w * 7 + d * 2 + 1) * 86_400
                let date = now.addingTimeInterval(-day)
                let gym = (w + d) % 2 == 0 ? gymA : gymB
                let mine = machines.filter { $0.gymID == gym.id }
                var entries: [MachineEntry] = []
                for (i, m) in mine.enumerated() {
                    var sets: [GymSet] = []
                    for s in 0..<4 {
                        let kg = Double(20 + i * 5 + w / 8) + Double(s)
                        sets.append(GymSet(kg: kg, reps: 8 + s))
                    }
                    entries.append(MachineEntry(machineID: m.id, sets: sets))
                }
                visits.append(GymVisit(gymID: gym.id, date: date, entries: entries,
                                       started: date, finished: date.addingTimeInterval(3_600)))
            }
        }
        let log = GymLog(machines: machines, visits: visits, gyms: [gymA, gymB], currentGymID: gymA.id)

        var workouts: [Workout] = []
        for i in 0..<30 {
            let kind: WorkoutKind = i % 2 == 0 ? .reps : .intervals
            workouts.append(Workout(name: "Workout \(i)", kind: kind))
        }
        var records: [SessionRecord] = []
        for i in 0..<300 {
            let w = workouts[i % workouts.count]
            let start = now.addingTimeInterval(-Double(i) * 2 * 86_400)
            records.append(SessionRecord(workoutID: w.id, kind: w.kind, name: w.name, colour: w.colour,
                                         started: start, ended: start.addingTimeInterval(1_800),
                                         completed: i % 5 != 0, detail: "5 of 5 sets"))
        }
        var photos: [String: Data] = [:]
        for i in 0..<200 {
            var bytes = [UInt8](repeating: 0, count: 300_000)
            arc4random_buf(&bytes, bytes.count)
            photos["photo\(i).jpg"] = Data(bytes)
        }
        return Big(log: log, records: records, workouts: workouts, photos: photos)
    }

    nonisolated(unsafe) static var big: Big = make()

    func timed<T>(_ label: String, _ limit: TimeInterval, _ body: () throws -> T) rethrows -> T {
        let t0 = Date()
        let result = try body()
        let dt = Date().timeIntervalSince(t0)
        print("LARGEDATA \(label): \(String(format: "%.3f", dt)) s")
        XCTAssertLessThan(dt, limit, "\(label) took \(dt) s")
        return result
    }

    func testDataShape() {
        let b = Self.big
        XCTAssertEqual(b.log.visits.count, 312)
        XCTAssertEqual(b.log.machines.count, 16)
        XCTAssertEqual(b.log.visits.reduce(0) { $0 + $1.setCount }, 312 * 32)
        XCTAssertEqual(b.records.count, 300)
        XCTAssertEqual(b.workouts.count, 30)
        XCTAssertEqual(b.photos.count, 200)
    }

    func testGymFileRoundTrip() throws {
        let log = Self.big.log
        let data = try timed("GymFile.encode", 5) { try GymFile.encode(log) }
        let back = try timed("GymFile.decode", 5) { try GymFile.decode(data) }
        XCTAssertEqual(back, log)
    }

    func testHistoryItemsWeeklyTotals() {
        let b = Self.big
        let items = timed("History.items", 2) { History.items(records: b.records, gym: b.log) }
        XCTAssertEqual(items.count, 312 + 300)
        let weekly = timed("History.weekly", 2) { History.weekly(items, weeks: 8, now: Self.now, calendar: Self.cal) }
        XCTAssertEqual(weekly.count, 8)
        let weekly104 = timed("History.weekly 104 weeks", 2) { History.weekly(items, weeks: 104, now: Self.now, calendar: Self.cal) }
        XCTAssertEqual(weekly104.count, 104)
        let everything = DateInterval(start: .distantPast, end: .distantFuture)
        let t = timed("History.totals", 2) { History.totals(items, in: everything) }
        XCTAssertEqual(t.sessions, items.count)
        let streak = timed("History.weekStreak", 2) { History.weekStreak(items, now: Self.now, calendar: Self.cal) }
        XCTAssertGreaterThan(streak, 50)
    }

    func testBackupWithPhotos() throws {
        let b = Self.big
        let files: [String: Data] = [
            "workouts.json": try WorkoutFile.encode(b.workouts),
            "gym.json": try GymFile.encode(b.log),
            "history.json": try HistoryFile.encode(b.records),
        ]
        let backup = Backup(made: Self.now, files: files, photos: b.photos)
        let data = try timed("Backup.encode", 20) { try Backup.encode(backup) }
        print("LARGEDATA backup size: \(data.count / 1_000_000) MB")
        let back = try timed("Backup.decode", 20) { try Backup.decode(data) }
        let contents = try timed("Backup.contents", 20) { try back.contents() }
        XCTAssertEqual(contents.workouts, 30)
        XCTAssertEqual(contents.machines, 16)
        XCTAssertEqual(contents.visits, 312)
        XCTAssertEqual(contents.records, 300)
        XCTAssertEqual(contents.photos, 200)
        XCTAssertEqual(back.photos, b.photos)
    }

    func testGymLogLookupsOnTheBigLog() {
        let log = Self.big.log
        let newest = log.visitsNewestFirst[0]
        timed("GymLog next/best/history/last for all machines", 1) {
            for m in log.machines {
                _ = log.next(m.id, in: newest)
                _ = log.best(m.id)
                _ = log.last(m.id)
                XCTAssertFalse(log.history(m.id).isEmpty)
            }
        }
        timed("GymLog.lastOrder", 1) {
            for g in log.gyms {
                _ = log.lastOrder(gym: g.id, before: Self.now, calendar: Self.cal)
            }
        }
    }
}
