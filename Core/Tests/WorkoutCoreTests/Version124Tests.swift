import XCTest
@testable import WorkoutCore

/// 1.24: the file for the Garmin Board — finished sessions only, newest first, with their machines.
final class Version124Tests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func testTheBoardFileHoldsFinishedSessionsNewestFirst() throws {
        let press = Machine(name: "Leg press")
        var log = GymLog(machines: [press])
        log.ensureGym()
        let gym = log.currentGym?.id
        log.machines[0].gymID = gym
        let d1 = Date(timeIntervalSince1970: 1_792_000_000), d2 = d1.addingTimeInterval(3 * 86_400), d3 = d2.addingTimeInterval(86_400)
        for (day, kg) in [(d1, 50.0), (d2, 55.0)] {
            log.add(GymSet(kg: kg, reps: 12), machine: press.id, on: day, now: day, calendar: cal)
            log.add(GymSet(kg: kg, reps: 10), machine: press.id, on: day, now: day.addingTimeInterval(300), calendar: cal)
            let v = log.openVisit(on: day, gym: gym, calendar: cal)!
            log.finish(visit: v.id, at: day.addingTimeInterval(400), calendar: cal)
        }
        // A session still going is not in the file.
        log.add(GymSet(kg: 55, reps: 12), machine: press.id, on: d3, now: d3, calendar: cal)
        let second = log.visits(on: d2, gym: gym, calendar: cal)[0]
        log.feel(visit: second.id, .good)
        log.pain(visit: second.id, machine: press.id, true)

        let file = log.boardFile(now: d3, calendar: cal)
        XCTAssertEqual(file.format, 1)
        XCTAssertEqual(file.sessions.count, 2)
        let s = file.sessions[0]
        XCTAssertEqual(s.id, second.id)
        XCTAssertEqual(s.feel, "good")
        XCTAssertEqual(s.sets, 2)
        XCTAssertEqual(s.machines, 1)
        XCTAssertEqual(s.liftedKg, 55 * 22)
        XCTAssertEqual(s.bests, ["Leg press"])
        XCTAssertEqual(s.entries.first?.name, "Leg press")
        XCTAssertEqual(s.entries.first?.topKg, 55)
        XCTAssertEqual(s.entries.first?.pain, true)
        XCTAssertEqual(s.minutes, 6)
        XCTAssertEqual(s.date.count, 10)

        let back = try JSONSerialization.jsonObject(with: file.encoded()) as? [String: Any]
        XCTAssertEqual(back?["app"] as? String, "AMS Workout Companion")
        XCTAssertEqual((back?["sessions"] as? [[String: Any]])?.count, 2)
    }

    func testAnEmptyLogGivesAnEmptyFile() throws {
        XCTAssertTrue(GymLog().boardFile().sessions.isEmpty)
        XCTAssertEqual(BoardFile.name, "Workout Companion sessions.json")
    }
}
