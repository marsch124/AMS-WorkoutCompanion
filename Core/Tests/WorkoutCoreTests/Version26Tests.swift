import XCTest
@testable import WorkoutCore

/// 2.6: a step has an effort — Easy, Steady, Hard or All-out — shown first and read out first.
final class Version26Tests: XCTestCase {
    private func hill() -> Workout {
        var jog = IntervalStep(name: "Jog", seconds: 60, effort: .steady)
        jog.set(.pace, 330)
        jog.set(.power, 150)
        let walk = IntervalStep(name: "Walk", seconds: 60, effort: .easy)
        return Workout(name: "Hill", kind: .tailored, steps: [jog, walk], measures: [.pace, .power])
    }

    func testTheFourEffortsAndTheirTitles() {
        XCTAssertEqual(StepEffort.allCases, [.easy, .steady, .hard, .allOut])
        XCTAssertEqual(StepEffort.allCases.map(\.title), ["Easy", "Steady", "Hard", "All-out"])
        XCTAssertEqual(IntervalStep(name: "Jog", seconds: 60).effort, nil)
    }

    func testTheExampleHasEffortsAndNoNumbers() {
        let steps = IntervalStep.example
        XCTAssertEqual(steps.count, 10)
        XCTAssertTrue(steps.filter { $0.name == "Jog" }.allSatisfy { $0.effort == .steady })
        XCTAssertTrue(steps.filter { $0.name == "Walk" }.allSatisfy { $0.effort == .easy })
        XCTAssertTrue(steps.allSatisfy { $0.values.isEmpty && $0.shownTarget == nil })
    }

    func testAddStepCopiesTheEffortFromTwoLinesUp() {
        let next = hill().nextStep()
        XCTAssertEqual(next.name, "Jog")
        XCTAssertEqual(next.effort, .steady)
        let one = Workout(name: "One", kind: .tailored, steps: [IntervalStep(name: "Jog", seconds: 60, effort: .hard)])
        XCTAssertNil(one.nextStep().effort)
    }

    func testTheEffortComesFirstInTheDetailAndTheSpokenWords() {
        let w = hill()
        XCTAssertEqual(w.detail(at: 0), "Steady \u{B7} 5:30 /km \u{B7} 150 W")
        XCTAssertEqual(w.detail(at: 1), "Easy")
        XCTAssertEqual(w.spokenDetail(at: 0), "Steady. 5:30 per kilometre. 150 watts")
        let bare = Workout(name: "Bare", kind: .tailored, steps: [IntervalStep(name: "Jog", seconds: 60)])
        XCTAssertNil(bare.detail(at: 0))
    }

    func testThePlanLineCarriesTheEffort() {
        let w = hill()
        XCTAssertEqual(w.plan.first, PlanLine("1 \u{B7} Jog", "1:00 \u{B7} Steady \u{B7} 5:30 /km \u{B7} 150 W"))
        XCTAssertEqual(w.plan[1], PlanLine("2 \u{B7} Walk", "1:00 \u{B7} Easy"))
    }

    func testOnlyEasyRunsOnAGreyRing() {
        for e in StepEffort.allCases {
            XCTAssertEqual(IntervalStep(name: "S", seconds: 30, effort: e).isCalm, e == .easy, e.title)
        }
        XCTAssertFalse(IntervalStep(name: "S", seconds: 30).isCalm)
    }

    func testEffortSurvivesTheFileAndOldStepsAreRead() throws {
        let made = Workout(name: "Max", kind: .tailored, steps: [IntervalStep(name: "Sprint", seconds: 20, effort: .allOut)])
        let back = try XCTUnwrap(WorkoutFile.decode(WorkoutFile.encode([made])).first)
        XCTAssertEqual(back.steps[0].effort, .allOut)
        func old(_ extra: String) throws -> IntervalStep {
            let json = #"{"version":1,"workouts":[{"id":"5B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Old","kind":"tailored","colour":"violet","steps":[{"id":"6B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Jog","seconds":90\#(extra)}]}]}"#
            return try XCTUnwrap(WorkoutFile.decode(Data(json.utf8)).first?.steps.first)
        }
        XCTAssertEqual(try old(#","easy":true"#).effort, .easy)
        XCTAssertNil(try old(#","easy":false"#).effort)
        XCTAssertNil(try old("").effort)
    }
}
