import XCTest
@testable import WorkoutCore

/// 1.8: the week picture's sessions, and the "Check my data" report.
final class WeekAndHealthTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        c.firstWeekday = 2
        return c
    }()
    func day(_ d: Int, _ month: Int = 11) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: d, hour: 18))!
    }
    func record(_ name: String, _ d: Int, _ month: Int = 11) -> SessionRecord {
        SessionRecord(workoutID: nil, kind: .reps, name: name, colour: "green",
                      started: day(d, month), ended: day(d, month).addingTimeInterval(600), completed: true, detail: "5 of 5 sets")
    }

    // MARK: Week picture

    func testTwelveWeeksWithSessionsAndMinutes() {
        let items = History.items(records: [record("A", 3), record("B", 4), record("C", 20, 10)], gym: GymLog())
        let bars = History.weekly(items, weeks: 12, now: day(5), calendar: cal)
        XCTAssertEqual(bars.count, 12)
        XCTAssertEqual(bars.last?.sessions, 2)
        XCTAssertEqual(bars.last?.minutes, 20)
        XCTAssertEqual(bars.first(where: { $0.start == History.period(.weekOfYear, around: day(20, 10), calendar: cal).start })?.sessions, 1)
    }

    func testSessionsOfOneWeekNewestFirstAndOnlyThatWeek() {
        let items = History.items(records: [record("Mon", 2), record("Wed", 4), record("Last week", 30, 10)], gym: GymLog())
        let start = History.period(.weekOfYear, around: day(4), calendar: cal).start
        let inWeek = History.sessions(items, weekStarting: start, calendar: cal)
        XCTAssertEqual(inWeek.map(\.name), ["Wed", "Mon"])
        XCTAssertEqual(History.sessions(items, weekStarting: day(1, 9), calendar: cal).count, 0)
    }

    // MARK: Health check

    func good() throws -> [String: Data?] {
        let w = Workout(name: "Push", kind: .reps)
        return ["workouts.json": try WorkoutFile.encode([w]),
                "gym.json": try GymFile.encode(GymLog(machines: [Machine(name: "Press", photo: "a.jpg")])),
                "history.json": try HistoryFile.encode([record("A", 3)])]
    }

    func testAllGood() throws {
        let r = HealthCheck.run(files: try good(), photoNames: ["a.jpg"], otherFileNames: ["Photos", "workouts.json"])
        XCTAssertTrue(r.isAllGood)
        XCTAssertEqual(r.problems, [])
        XCTAssertEqual(r.workouts, 1)
        XCTAssertEqual(r.machines, 1)
        XCTAssertEqual(r.otherSessions, 1)
        XCTAssertEqual(r.photos, 1)
    }

    func testMissingFilesAreFineForANewApp() {
        let r = HealthCheck.run(files: [:], photoNames: [], otherFileNames: [])
        XCTAssertTrue(r.isAllGood)
    }

    func testADamagedGymFile() throws {
        var f = try good()
        f["gym.json"] = Data("{ not json".utf8)
        let r = HealthCheck.run(files: f, photoNames: ["a.jpg"], otherFileNames: [])
        XCTAssertFalse(r.isAllGood)
        XCTAssertEqual(r.problems.count, 1)
        XCTAssertTrue(r.problems[0].contains("gym"))
        XCTAssertEqual(r.workouts, 1)
    }

    func testAMissingPhoto() throws {
        let r = HealthCheck.run(files: try good(), photoNames: [], otherFileNames: [])
        XCTAssertEqual(r.missingPhotos, ["a.jpg"])
        XCTAssertEqual(r.problems.count, 1)
        XCTAssertTrue(r.problems[0].contains("photo"))
    }

    func testAnUnreadableFileKeptAside() throws {
        let r = HealthCheck.run(files: try good(), photoNames: ["a.jpg"],
                                otherFileNames: ["gym-unreadable-1790000000.json", "Before restore 1790000001"])
        XCTAssertEqual(r.keptAside, ["gym-unreadable-1790000000.json"])
        XCTAssertEqual(r.beforeRestoreFolders, ["Before restore 1790000001"])
        XCTAssertEqual(r.problems.count, 1)
        XCTAssertTrue(r.problems[0].contains("kept aside"))
    }
}
