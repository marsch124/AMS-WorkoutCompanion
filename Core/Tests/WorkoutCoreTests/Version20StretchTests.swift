import XCTest
@testable import WorkoutCore

final class Version20StretchTests: XCTestCase {
    func testLibraryHasGuidesAndEveryOldNameIsMappedOrNil() {
        XCTAssertEqual(StretchLibrary.stretches.count, 30)
        XCTAssertEqual(StretchLibrary.moves.count, 10)
        for i in StretchLibrary.all { XCTAssertNotNil(StretchLibrary.guide(i.id), i.id) }
        let old = StretchRoutine.all.flatMap(\.moves).map(\.name)
        XCTAssertEqual(old.count, 37)
        for n in old { if let a = StretchLibrary.alias(for: n) { XCTAssertNotNil(StretchLibrary.item(a), n) } }
        XCTAssertNil(StretchLibrary.alias(for: "Happy baby"))
        XCTAssertEqual(StretchLibrary.alias(for: "Thigh, standing"), "quad-standing")
    }

    func testMigrationKeepsOrderMakesUnknownCustomAndIsIdempotent() {
        let w = Workout(name: "Mine", kind: .checklist, exercises: [
            Exercise(name: "Child's pose", amount: "60 s"),
            Exercise(name: "Happy baby", amount: "45 s each side", note: "Hold the feet.", photo: "p.jpg"),
            Exercise(name: "Thigh, standing", amount: "30 s each side")])
        let before = w
        var gym = GymLog()
        gym.stretchID = w.id
        gym.migrateStretchBook(workouts: [w])
        let b = gym.stretchBook!
        XCTAssertEqual(b.migratedFrom, w.id)
        XCTAssertEqual(b.ticked.count, 3)
        XCTAssertEqual(b.ticked[0], "childs-pose")
        XCTAssertEqual(b.ticked[2], "quad-standing")
        let c = b.custom(b.ticked[1])!
        XCTAssertEqual(c.name, "Happy baby")
        XCTAssertEqual(c.seconds, 45); XCTAssertEqual(c.sides, 2)
        XCTAssertEqual(c.note, "Hold the feet."); XCTAssertEqual(c.photo, "p.jpg")
        gym.stretchBook?.add("cobra")
        gym.migrateStretchBook(workouts: [w])
        XCTAssertTrue(gym.stretchBook!.ticked.contains("cobra"))
        XCTAssertEqual(w, before)
        var none = GymLog()
        none.migrateStretchBook(workouts: [])
        XCTAssertEqual(none.stretchBook!.ticked, StretchBook.defaultTicks)
    }

    func testSuggestedFollowsTheMusclesOfTheMachinesDone() {
        var gym = GymLog()
        gym.muscles.append(MuscleGroup(id: "x1", name: "Big legs", colour: "green"))
        let m = Machine(name: "Press"); var press = m; press.muscle = "x1"
        gym.machines = [press]
        var v = GymVisit(date: Date())
        v.entries = [MachineEntry(machineID: press.id)]
        XCTAssertEqual(gym.trainedMuscles(in: v), ["legs"])
        let s = gym.suggestedStretches(for: v)
        XCTAssertTrue(s.contains("quad-standing")); XCTAssertTrue(s.contains("legs-up"))
        XCTAssertFalse(s.contains("neck-side"))
        XCTAssertLessThanOrEqual(s.count, 12)
        XCTAssertEqual(gym.trainedWords(in: v), "legs")
        XCTAssertTrue(gym.suggestedStretches(for: nil).isEmpty)
    }

    func testHoldOverrideReachesTheTimer() {
        var b = StretchBook()
        XCTAssertEqual(b.pick("quad-standing")?.seconds, 30)
        b.setHold("quad-standing", seconds: 45)
        let p = b.picks(["quad-standing", "legs-up"])
        XCTAssertEqual(p[0].seconds, 45)
        let ph = StretchTimer.phases(for: p)
        XCTAssertEqual(ph.filter { $0.kind == .hold }.first?.seconds, 45)
        XCTAssertEqual(ph.first?.figureID, "quad-standing")
        XCTAssertEqual(ph.count, 4 + 2)
    }
}
