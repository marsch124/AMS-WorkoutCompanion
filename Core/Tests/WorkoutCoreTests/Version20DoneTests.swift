import XCTest
@testable import WorkoutCore

/// 2.0 Well done: the week count and the Board file's warm-up and stretch fields.
final class Version20DoneTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 12))! }

    func testSessionsThisWeekStartsOnMonday() {
        var log = GymLog()
        // 16 Nov 2026 is a Monday. Sunday 15th belongs to the week before.
        for d in [15, 16, 18, 22, 23] { log.visits.append(GymVisit(date: day(d), finished: day(d))) }
        let open = GymVisit(date: day(19))
        log.visits.append(open)
        XCTAssertEqual(log.sessionsThisWeek(containing: day(19), calendar: cal), 3)
        XCTAssertEqual(log.sessionsThisWeek(containing: day(19), including: open.id, calendar: cal), 4)
        XCTAssertEqual(log.sessionsThisWeek(containing: day(15), calendar: cal), 1)
    }

    private func finishedLog(warm: Bool) -> (GymLog, GymVisit) {
        var log = GymLog()
        let m = Machine(name: "Leg press")
        log.machines.append(m)
        var set = GymSet(kg: 50, reps: 10)
        set.at = day(19)
        var v = GymVisit(date: day(19), entries: [MachineEntry(machineID: m.id, sets: [set])], started: day(19), finished: day(19))
        if warm {
            var w = VisitPart(kind: .cardio, start: day(19).addingTimeInterval(-600), end: day(19).addingTimeInterval(-120))
            w.speed = 9.5; w.heartRate = 128
            v.warmup = w
            var s = VisitPart(kind: .stretch, start: day(19), end: day(19).addingTimeInterval(540))
            s.held = 6
            v.stretching = s
        }
        log.visits.append(v)
        return (log, v)
    }

    func testBoardFieldsOnlyWhenSet() throws {
        let (plain, _) = finishedLog(warm: false)
        let json = String(data: try plain.boardFile(calendar: cal).encoded(), encoding: .utf8)!
        XCTAssertFalse(json.contains("warmup"))
        XCTAssertFalse(json.contains("stretch"))
        XCTAssertTrue(json.contains("\"format\" : 1"))
        let (full, _) = finishedLog(warm: true)
        let s = full.boardSessions(calendar: cal)[0]
        XCTAssertEqual(s.warmupMinutes, 8)
        XCTAssertEqual(s.warmupKind, "cardio")
        XCTAssertEqual(s.warmupSpeed, 9.5)
        XCTAssertEqual(s.warmupHeartRate, 128)
        XCTAssertEqual(s.stretchMinutes, 9)
        XCTAssertEqual(s.stretchCount, 6)
    }

    func testShareLines() {
        let (log, v) = finishedLog(warm: true)
        XCTAssertEqual(v.stretchLine(), "Stretching 9 min · 6 stretches")
        XCTAssertTrue(v.warmupLine(in: log)!.hasPrefix("Warm-up 8 min · "))
        XCTAssertEqual(GymVisit.ordinal(3), "3rd")
        XCTAssertEqual(GymVisit.ordinal(12), "12th")
    }
}
