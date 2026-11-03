import XCTest
@testable import WorkoutCore

/// Version 1.10: muscle groups you can change, and plans saved as templates.
final class MusclesAndTemplatesTests: XCTestCase {
    let gymA = UUID(), gymB = UUID()

    // MARK: Muscle groups

    func testA19FileKeepsItsMusclesAndGetsTheSevenGroups() throws {
        // A gym.json from 1.9: no "muscles", a machine with "muscle":"legs".
        let id = UUID()
        let json = """
        {"version":1,"machines":[{"id":"\(id)","name":"Leg press","setting":"","muscle":"legs"}],"visits":[]}
        """
        let log = try GymFile.decode(Data(json.utf8))
        XCTAssertEqual(log.muscles.map(\.name), ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio"])
        XCTAssertEqual(log.muscle(for: log.machine(id))?.name, "Legs")
        XCTAssertEqual(log.muscle(for: log.machine(id))?.colour, "green")
    }

    func testRenameAddArrangeAndColourSurviveTheFile() throws {
        var log = GymLog()
        var legs = try XCTUnwrap(log.muscle("legs"))
        legs.name = "  Lower body "
        legs.colour = "plum"
        log.save(muscle: legs)
        log.save(muscle: MuscleGroup(name: "Glutes", colour: "pink"))
        log.save(muscle: MuscleGroup(name: "   ", colour: "red")) // no name: not saved
        log.moveMuscles(from: [7], to: 0)
        let back = try GymFile.decode(GymFile.encode(log))
        XCTAssertEqual(back.muscles.map(\.name), ["Glutes", "Chest", "Back", "Shoulders", "Arms", "Lower body", "Core", "Cardio"])
        XCTAssertEqual(back.muscle("legs")?.colour, "plum")
    }

    func testMoveDownKeepsTheOthersInOrder() {
        var log = GymLog()
        log.moveMuscles(from: [0], to: 3) // Chest below Shoulders, like a drag in a List
        XCTAssertEqual(log.muscles.prefix(4).map(\.id), ["back", "shoulders", "chest", "arms"])
    }

    func testDeletingAGroupSendsItsMachinesToNotChosenAndKeepsTheSets() {
        var press = Machine(name: "Chest press")
        press.muscle = "chest"
        var log = GymLog(machines: [press])
        log.add(GymSet(kg: 30, reps: 10), machine: press.id, on: Date())
        XCTAssertEqual(log.machineCount(muscle: "chest"), 1)
        log.delete(muscle: "chest")
        XCTAssertNil(log.muscle("chest"))
        XCTAssertNil(log.machine(press.id)?.muscle)
        XCTAssertEqual(log.visits.first?.setCount, 1)
        let week = DateInterval(start: Date().addingTimeInterval(-3600), duration: 7200)
        XCTAssertEqual(Stats.muscles(log, in: week), [MuscleCount(muscle: nil, sets: 1)])
    }

    func testStatsFollowYourNamesAndOrderOnATie() {
        let a = MuscleGroup(id: "a", name: "Pull", colour: "blue"), b = MuscleGroup(id: "b", name: "Push", colour: "red")
        var m1 = Machine(name: "Row"), m2 = Machine(name: "Press")
        m1.muscle = "a"; m2.muscle = "b"
        var log = GymLog(machines: [m1, m2], muscles: [b, a])
        log.add(GymSet(kg: 20, reps: 10), machine: m1.id, on: Date())
        log.add(GymSet(kg: 20, reps: 10), machine: m2.id, on: Date())
        let week = DateInterval(start: Date().addingTimeInterval(-3600), duration: 7200)
        XCTAssertEqual(Stats.muscles(log, in: week).map { $0.muscle?.name }, ["Push", "Pull"])
    }

    func testATimeMachineCountsAsCardioOnlyWhileCardioExists() {
        var log = GymLog(machines: [Machine(name: "Treadmill", logs: .time)])
        XCTAssertEqual(log.muscle(for: log.machines[0])?.name, "Cardio")
        log.delete(muscle: MuscleGroup.cardioID)
        XCTAssertNil(log.muscle(for: log.machines[0]))
    }

    // MARK: Plan templates

    func testATemplateIsKeptPerGymAndTheSameNameReplacesIt() throws {
        let a = Machine(gymID: gymA, name: "A"), b = Machine(gymID: gymA, name: "B")
        var log = GymLog(machines: [a, b])
        XCTAssertNotNil(log.saveTemplate(named: " Leg day ", order: [a.id, b.id], gym: gymA))
        XCTAssertNil(log.saveTemplate(named: "", order: [a.id], gym: gymA))
        XCTAssertNil(log.saveTemplate(named: "Empty", order: [], gym: gymA))
        log.saveTemplate(named: "leg day", order: [b.id], gym: gymA)
        XCTAssertEqual(log.templates(gym: gymA).count, 1)
        XCTAssertEqual(log.templates(gym: gymA).first?.order, [b.id])
        XCTAssertEqual(log.templates(gym: gymB), [])
        let back = try GymFile.decode(GymFile.encode(log))
        XCTAssertEqual(back.templates(gym: gymA).first?.name, "leg day")
    }

    func testADeletedMachineDropsOutOfItsTemplates() {
        let a = Machine(gymID: gymA, name: "A"), b = Machine(gymID: gymA, name: "B")
        var log = GymLog(machines: [a, b])
        log.saveTemplate(named: "Both", order: [a.id, b.id], gym: gymA)
        log.saveTemplate(named: "Only A", order: [a.id], gym: gymA)
        log.delete(machine: a.id)
        XCTAssertEqual(log.templates.map(\.name), ["Both"])
        XCTAssertEqual(log.order(of: log.templates[0]), [b.id])
        log.deleteTemplate(log.templates[0].id)
        XCTAssertEqual(log.templates, [])
    }
}
