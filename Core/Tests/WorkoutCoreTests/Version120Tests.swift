import XCTest
@testable import WorkoutCore

/// Version 1.20: a session starts when the gym screen opens (his ask), not at the first set.
final class Version120Tests: XCTestCase {
    let gym = UUID()
    let nine = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

    private func log() -> (GymLog, Machine) {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        let m = Machine(gymID: gym, name: "Leg press")
        l.save(m)
        return (l, m)
    }

    func testOpeningTheGymStartsTheSessionClock() {
        var (l, m) = log()
        XCTAssertNil(l.sessionStart(on: nine, gym: gym))
        l.arrive(gym: gym, at: nine)
        XCTAssertEqual(l.sessionStart(on: nine, gym: gym), nine)
        XCTAssertTrue(l.visits.isEmpty, "opening the gym saves no visit")
        // Opening it again later keeps the first time.
        l.arrive(gym: gym, at: nine.addingTimeInterval(600))
        XCTAssertEqual(l.sessionStart(on: nine, gym: gym), nine)
        // The first set, 10 minutes later, belongs to a session that began at nine.
        l.add(GymSet(kg: 40, reps: 10), machine: m.id, on: nine, now: nine.addingTimeInterval(600))
        XCTAssertEqual(l.openVisit(on: nine, gym: gym)?.started, nine)
        XCTAssertEqual(l.sessionStart(on: nine, gym: gym), nine)
        XCTAssertNil(l.arrived, "the opening time moved into the visit")
    }

    func testFinishWithoutASetEndsItAndSavesNothing() {
        var (l, _) = log()
        l.arrive(gym: gym, at: nine)
        l.leave()
        XCTAssertNil(l.sessionStart(on: nine, gym: gym))
        XCTAssertTrue(l.visits.isEmpty)
    }

    func testAfterFinishOpeningTheGymDoesNotStartAnotherSession() {
        var (l, m) = log()
        l.arrive(gym: gym, at: nine)
        l.add(GymSet(kg: 40, reps: 10), machine: m.id, on: nine, now: nine.addingTimeInterval(60))
        l.finish(visit: l.visits[0].id, at: nine.addingTimeInterval(3600))
        l.arrive(gym: gym, at: nine.addingTimeInterval(7200))
        XCTAssertNil(l.sessionStart(on: nine, gym: gym), "a second session starts with its first set, as before")
    }

    func testYesterdaysOpeningDoesNotCountToday() {
        var (l, _) = log()
        l.arrive(gym: gym, at: nine.addingTimeInterval(-86_400))
        XCTAssertNil(l.sessionStart(on: nine, gym: gym))
    }

    func testTheOpeningTimeIsKeptInTheFile() throws {
        var (l, _) = log()
        l.arrive(gym: gym, at: nine)
        let back = try GymFile.decode(GymFile.encode(l))
        XCTAssertEqual(back.sessionStart(on: nine, gym: gym)?.timeIntervalSince1970.rounded(), nine.timeIntervalSince1970.rounded())
    }
}
