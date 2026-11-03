import XCTest
@testable import WorkoutCore

final class GymTests: XCTestCase {
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

    func testSwedishWeightsHaveAComma() {
        GymSet.locale = Locale(identifier: "sv_SE")
        XCTAssertEqual(GymSet(kg: 32.5, reps: 10).text, "32,5 kg × 10")
        XCTAssertEqual(GymSet.number(1250), "1250")
    }

    let press = Machine(name: "Chest press")
    let leg = Machine(name: "Leg press")

    func testSetsOnTheSameDayGoIntoOneVisitAndOneEntryPerMachine() {
        var log = GymLog(machines: [press, leg])
        log.add(GymSet(kg: 30, reps: 12), machine: press.id, on: day(3), calendar: cal)
        log.add(GymSet(kg: 40, reps: 10), machine: leg.id, on: day(3, 19), calendar: cal)
        log.add(GymSet(kg: 30, reps: 11), machine: press.id, on: day(3, 20), calendar: cal)
        XCTAssertEqual(log.visits.count, 1)
        XCTAssertEqual(log.visits[0].entries.count, 2)
        XCTAssertEqual(log.visits[0].entries[0].sets.map(\.reps), [12, 11])
        XCTAssertEqual(log.visits[0].setCount, 3)
        XCTAssertEqual(log.visits[0].totalKg, 30 * 12 + 40 * 10 + 30 * 11)
    }

    func testANewMachineStartsAt20KgTimes10() {
        let log = GymLog(machines: [press])
        XCTAssertEqual(log.next(press.id, in: GymVisit(date: day(3))), NextSet(set: GymSet(kg: 20, reps: 10), reason: nil))
    }

    func testTheNextSetRepeatsTheSetJustDone() {
        var log = GymLog(machines: [press])
        log.add(GymSet(kg: 35, reps: 9), machine: press.id, on: day(3), calendar: cal)
        XCTAssertEqual(log.next(press.id, in: log.visits[0]).set, GymSet(kg: 35, reps: 9))
    }

    func testTheFirstSetIsLastTimesFirstSet() {
        var log = GymLog(machines: [press])
        for r in [12, 11, 10] { log.add(GymSet(kg: 30, reps: r), machine: press.id, on: day(1), calendar: cal) }
        let today = GymVisit(date: day(3))
        XCTAssertEqual(log.next(press.id, in: today), NextSet(set: GymSet(kg: 30, reps: 12), reason: nil))
    }

    func testEveryTwelveRepsLastTimeSuggests2Point5KgMore() {
        var log = GymLog(machines: [press])
        for _ in 0..<3 { log.add(GymSet(kg: 30, reps: 12), machine: press.id, on: day(1), calendar: cal) }
        let next = log.next(press.id, in: GymVisit(date: day(3)))
        XCTAssertEqual(next.set, GymSet(kg: 32.5, reps: 10))
        XCTAssertEqual(next.reason, "Try 32.5 kg — every set last time reached 12 reps")
    }

    func testLastTimeIsTheNewestEarlierVisit() {
        var log = GymLog(machines: [press])
        log.add(GymSet(kg: 25, reps: 10), machine: press.id, on: day(1), calendar: cal)
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(2), calendar: cal)
        log.add(GymSet(kg: 35, reps: 8), machine: press.id, on: day(3), calendar: cal)
        let today = log.visit(on: day(3), calendar: cal)!
        XCTAssertEqual(log.last(press.id, excluding: today.id)?.entry.sets, [GymSet(kg: 30, reps: 10)])
    }

    func testAHeavierWeightThanEverIsANewBest() {
        var log = GymLog(machines: [press, leg])
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(1), calendar: cal)
        log.add(GymSet(kg: 40, reps: 10), machine: leg.id, on: day(1), calendar: cal)
        log.add(GymSet(kg: 32.5, reps: 8), machine: press.id, on: day(3), calendar: cal)
        log.add(GymSet(kg: 40, reps: 12), machine: leg.id, on: day(3), calendar: cal)
        XCTAssertEqual(log.newBests(in: log.visit(on: day(3), calendar: cal)!), [press.id])
        // A first time on a machine is no "best" yet.
        XCTAssertEqual(log.newBests(in: log.visit(on: day(1), calendar: cal)!), [])
    }

    func testRemovingTheLastSetRemovesTheEntryAndTheVisit() {
        var log = GymLog(machines: [press])
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(3), calendar: cal)
        let v = log.visits[0]
        log.change(visit: v.id, machine: press.id, set: 0, to: GymSet(kg: 30, reps: 9))
        XCTAssertEqual(log.visits[0].entries[0].sets, [GymSet(kg: 30, reps: 9)])
        log.change(visit: v.id, machine: press.id, set: 0, to: nil)
        XCTAssertTrue(log.visits.isEmpty)
    }

    func testDeletingAMachineRemovesItsSets() {
        var log = GymLog(machines: [press, leg])
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(3), calendar: cal)
        log.add(GymSet(kg: 40, reps: 10), machine: leg.id, on: day(3), calendar: cal)
        log.delete(machine: press.id)
        XCTAssertEqual(log.machines, [leg])
        XCTAssertEqual(log.visits[0].entries.map(\.machineID), [leg.id])
    }

    func testHistoryIsTheHeaviestPerVisitOldestFirst() {
        var log = GymLog(machines: [press])
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: day(2), calendar: cal)
        log.add(GymSet(kg: 25, reps: 12), machine: press.id, on: day(1), calendar: cal)
        log.add(GymSet(kg: 27.5, reps: 12), machine: press.id, on: day(1), calendar: cal)
        XCTAssertEqual(log.history(press.id).map(\.kg), [27.5, 30])
    }

    func testWordsForSets() {
        XCTAssertEqual(GymSet(kg: 32.5, reps: 10).text, "32.5 kg × 10")
        XCTAssertEqual(GymSet(kg: 0, reps: 15).text, "Body weight × 15")
        XCTAssertEqual(MachineEntry(machineID: press.id, sets: [GymSet(kg: 30, reps: 12), GymSet(kg: 30, reps: 10)]).text,
                       "30 kg × 12, 10")
        XCTAssertEqual(MachineEntry(machineID: press.id, sets: [GymSet(kg: 30, reps: 12), GymSet(kg: 32.5, reps: 8)]).text,
                       "30 × 12, 32.5 × 8 kg")
    }

    func testTheFileRoundTrips() throws {
        var log = GymLog(machines: [Machine(name: "Row", photo: "a.jpg", setting: "Seat 3")])
        log.add(GymSet(kg: 22.5, reps: 12), machine: log.machines[0].id, on: Date(timeIntervalSince1970: 1_793_000_000), calendar: cal)
        let back = try GymFile.decode(GymFile.encode(log))
        XCTAssertEqual(back.machines, log.machines)
        XCTAssertEqual(back.visits.first?.entries, log.visits.first?.entries)
        XCTAssertEqual(back.photosInUse, ["a.jpg"])
    }
}
