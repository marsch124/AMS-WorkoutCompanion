import XCTest
@testable import WorkoutCore

/// Version 1.16: the rest ring's colour, and sets that beat last time.
final class Version116Tests: XCTestCase {
    let gym = UUID()

    func testRestRingGoesFromOrangeToGreen() {
        XCTAssertEqual(RestColour.key(fractionLeft: 1), "orange")
        XCTAssertEqual(RestColour.key(fractionLeft: 0.6), "orange")
        XCTAssertEqual(RestColour.key(fractionLeft: 0.4), "yellow")
        XCTAssertEqual(RestColour.key(fractionLeft: 0.15), "green")
        XCTAssertEqual(RestColour.key(fractionLeft: 0), "green")
    }

    private func twoVisits(_ machine: inout Machine) -> (GymLog, UUID) {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(machine)
        let then = Date().addingTimeInterval(-7 * 86_400)
        l.add(GymSet(kg: 40, reps: 10), machine: machine.id, on: then)
        l.add(GymSet(kg: 40, reps: 8), machine: machine.id, on: then)
        l.finish(visit: l.visits[0].id)
        l.add(GymSet(kg: 10, reps: 15, warmup: true), machine: machine.id, on: Date())
        l.add(GymSet(kg: 42.5, reps: 8), machine: machine.id, on: Date())   // more weight than set 1 then
        l.add(GymSet(kg: 40, reps: 8), machine: machine.id, on: Date())     // the same as set 2 then
        return (l, l.openVisit(on: Date(), gym: gym)!.id)
    }

    func testASetBeatsTheSameSetLastTime() {
        var press = Machine(gymID: gym, name: "Press")
        let (l, visit) = twoVisits(&press)
        let today = l.openVisit(on: Date(), gym: gym)!.entries[0].sets
        XCTAssertFalse(l.beatsLastTime(today[0], at: 0, machine: press.id, visit: visit), "a warm-up never")
        XCTAssertTrue(l.beatsLastTime(today[1], at: 1, machine: press.id, visit: visit), "42.5 kg beats 40 kg")
        XCTAssertFalse(l.beatsLastTime(today[2], at: 2, machine: press.id, visit: visit), "the same is not more")
        XCTAssertFalse(l.beatsLastTime(GymSet(kg: 40, reps: 9), at: 9, machine: press.id, visit: visit),
                       "no set that far last time")
    }

    func testMoreRepsAtTheSameWeightBeatsIt() {
        var press = Machine(gymID: gym, name: "Press")
        let (l, visit) = twoVisits(&press)
        XCTAssertTrue(l.beatsLastTime(GymSet(kg: 40, reps: 9), at: 2, machine: press.id, visit: visit))
        XCTAssertFalse(l.beatsLastTime(GymSet(kg: 37.5, reps: 12), at: 2, machine: press.id, visit: visit),
                       "less weight is not more, even with more reps")
    }

    func testRepsOnlyCountsReps() {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        var push = Machine(gymID: gym, name: "Push-ups")
        push.logs = .reps
        l.save(push)
        l.add(GymSet(kg: 0, reps: 15), machine: push.id, on: Date().addingTimeInterval(-86_400))
        l.finish(visit: l.visits[0].id)
        l.add(GymSet(kg: 0, reps: 16), machine: push.id, on: Date())
        let visit = l.openVisit(on: Date(), gym: gym)!
        XCTAssertTrue(l.beatsLastTime(visit.entries[0].sets[0], at: 0, machine: push.id, visit: visit.id))
    }

    func testFirstTimeOnAMachineBeatsNothing() {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        let row = Machine(gymID: gym, name: "Row")
        l.save(row)
        l.add(GymSet(kg: 30, reps: 10), machine: row.id, on: Date())
        let visit = l.openVisit(on: Date(), gym: gym)!
        XCTAssertFalse(l.beatsLastTime(visit.entries[0].sets[0], at: 0, machine: row.id, visit: visit.id))
    }
}
