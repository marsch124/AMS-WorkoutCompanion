import XCTest
@testable import WorkoutCore

/// 2.4: a step of a Tailored intervals workout carries a speed or power, and is Effort or Easy.
final class Version24Tests: XCTestCase {
    /// 2.4 had Jog as Effort and Walk as Easy; 2.5 removed Effort / Easy (his pick).
    func testTheExampleHasNoEasyStepsSince25() {
        XCTAssertTrue(IntervalStep.example.allSatisfy { !$0.easy && $0.shownTarget == nil && $0.values.isEmpty })
    }

    func testAddStepCopiesSpeedOrPowerAndEasyFromTwoLinesUp() {
        let w = Workout(name: "Hill", kind: .tailored, steps: [
            IntervalStep(name: "Jog", seconds: 60, target: "8 km/h"),
            IntervalStep(name: "Walk", seconds: 120, target: "5 km/h", easy: true),
        ])
        let next = w.nextStep()
        XCTAssertEqual(next.name, "Jog")
        XCTAssertEqual(next.target, "8 km/h")
        XCTAssertFalse(next.easy)
        XCTAssertEqual(next.seconds, 120)
        var longer = w
        longer.steps.append(next)
        XCTAssertEqual(longer.nextStep().target, "5 km/h")
    }

    func testTheVoiceSaysTheSpeedOrPowerAfterTheLength() {
        XCTAssertEqual(TailoredCue.start(name: "Jog", seconds: 120, isLast: false, target: "8 km/h"), "Jog. 2 minutes. 8 km/h.")
        XCTAssertEqual(TailoredCue.start(name: "Jog", seconds: 120, isLast: false, target: nil), "Jog. 2 minutes.")
    }

    func testPlanLinesAndNoticesCarryTheSpeedOrPower() {
        let w = Workout(name: "Hill", kind: .tailored, steps: [
            IntervalStep(name: "Jog", seconds: 60, target: " 150 W "),
            IntervalStep(name: "Walk", seconds: 60, easy: true),
        ])
        XCTAssertEqual(w.plan, [PlanLine("1 · Jog", "1:00 · 150 W"), PlanLine("2 · Walk", "1:00"), PlanLine("Total time", "2:00")])
        let notices = Plan.notices(phases: Plan.phases(for: w), index: 0, left: 5, name: "Hill", details: w.steps.indices.map { w.detail(at: $0) })
        XCTAssertEqual(notices.map(\.title), ["Jog · 1:00 · 150 W", "Walk · 1:00", "Workout complete"])
    }

    func testTheStepBehindARunningPhase() {
        let w = Workout(name: "Hill", kind: .tailored, steps: IntervalStep.example)
        let phases = Plan.phases(for: w)
        XCTAssertNil(w.step(of: phases[0]))
        XCTAssertEqual(w.step(of: phases[2])?.name, "Walk")
        XCTAssertEqual(w.stepIndex(of: phases[2]), 1)
    }

    func testAStepSavedWith23HasNoSpeedAndIsEffort() throws {
        let old = #"{"version":1,"workouts":[{"id":"5B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Old","kind":"tailored","colour":"violet","steps":[{"id":"6B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Jog","seconds":90}]}]}"#
        let step = try XCTUnwrap(WorkoutFile.decode(Data(old.utf8)).first?.steps.first)
        XCTAssertEqual(step.target, "")
        XCTAssertFalse(step.easy)
        let made = Workout(name: "New", kind: .tailored, steps: [IntervalStep(name: "Jog", seconds: 60, target: "8 km/h", easy: true)])
        XCTAssertEqual(try WorkoutFile.decode(WorkoutFile.encode([made])).first?.steps, made.steps)
    }
}
