import XCTest
@testable import WorkoutCore

/// 1.22: the "Done this session" list and the running session clock.
final class Version122Tests: XCTestCase {
    func testDoneListKeepsOrderAndSkipsMachinesWithoutSets() {
        let a = UUID(), b = UUID(), c = UUID()
        let visit = GymVisit(date: Date(), entries: [
            MachineEntry(machineID: a, sets: [GymSet(kg: 30, reps: 12)]),
            MachineEntry(machineID: b),
            MachineEntry(machineID: c, sets: [GymSet(kg: 20, reps: 10), GymSet(kg: 20, reps: 8)]),
        ])
        XCTAssertEqual(visit.performed.map(\.machineID), [a, c])
    }

    func testClockShowsHoursMinutesSeconds() {
        XCTAssertEqual(GymVisit.clock(0), "0:00:00")
        XCTAssertEqual(GymVisit.clock(42 * 60 + 15), "0:42:15")
        XCTAssertEqual(GymVisit.clock(3600 + 5 * 60 + 9), "1:05:09")
        XCTAssertEqual(GymVisit.clock(-5), "0:00:00")
    }
}
