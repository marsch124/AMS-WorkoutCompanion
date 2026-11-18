import XCTest
@testable import WorkoutCore

/// 1.28: the plan page's lines.
final class Version128Tests: XCTestCase {
    func testThePlanSaysWhatTheWorkoutHolds() {
        let reps = Workout(name: "Push-ups", kind: .reps, sets: 5, reps: 20, restSeconds: 90)
        XCTAssertEqual(reps.plan, [PlanLine("Sets", "5"), PlanLine("Reps each set", "20"),
                                   PlanLine("Rest between sets", "1:30")])
        XCTAssertEqual(Workout(kind: .reps, restSeconds: 0).plan.last, PlanLine("Rest between sets", "None"))

        let rounds = Workout(name: "Intervals", kind: .intervals, rounds: 8, workSeconds: 40, offSeconds: 20)
        XCTAssertEqual(rounds.plan.map(\.label), ["Rounds", "Work", "Rest", "Total time"])
        XCTAssertEqual(rounds.plan.map(\.value), ["8", "0:40", "0:20", Clock.text(rounds.intervalTotal)])

        XCTAssertTrue(Workout(kind: .checklist, exercises: [Exercise(name: "Bridge")]).plan.isEmpty)
    }
}
