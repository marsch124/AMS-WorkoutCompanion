import XCTest
@testable import WorkoutCore

/// 2.3: the fourth kind, Tailored intervals: a free list of steps, each with a name and a length.
final class Version23Tests: XCTestCase {
    private func pyramid() -> Workout { Workout(name: "Pyramid", kind: .tailored, steps: IntervalStep.example) }

    func testTheExampleIsTenStepsAndEighteenMinutes() {
        let w = Workout.starting(.tailored)
        XCTAssertEqual(w.kind.rawValue, "tailored")
        XCTAssertEqual(w.kind.title, "Tailored intervals")
        XCTAssertEqual(w.steps.count, 10)
        XCTAssertEqual(w.tailoredTotal, 1080)
        XCTAssertEqual(Clock.text(w.tailoredTotal), "18:00")
    }

    func testPhasesAreGetReadyThenOneStepEach() {
        let phases = Plan.phases(for: pyramid())
        XCTAssertEqual(phases.count, 11)
        XCTAssertEqual(phases[0], .getReady(seconds: 5))
        XCTAssertEqual(phases[1], .step(seconds: 60, name: "Jog", number: 1, of: 10))
        XCTAssertEqual(phases[10], .step(seconds: 60, name: "Walk", number: 10, of: 10))
        XCTAssertFalse(phases[3].isRest)
        XCTAssertEqual(phases[3].seconds, 120)
        XCTAssertEqual(Plan.phases(for: Workout(name: "Empty", kind: .tailored, steps: [])), [])
    }

    func testSummary() {
        XCTAssertEqual(pyramid().summary, "10 steps · 18:00")
        XCTAssertEqual(Workout(name: "One", kind: .tailored, steps: [IntervalStep(name: "Jog", seconds: 60)]).summary, "1 step · 1:00")
        XCTAssertEqual(Workout(name: "None", kind: .tailored, steps: []).summary, "No steps yet")
    }

    func testPlanLines() {
        let plan = pyramid().plan
        XCTAssertEqual(plan.count, 11)
        XCTAssertEqual(plan.first, PlanLine("1 · Jog", "1:00 · Steady"))
        XCTAssertEqual(plan.last, PlanLine("Total time", "18:00"))
    }

    func testAnEmptyStepNameIsItsNumber() {
        let w = Workout(name: "W", kind: .tailored, steps: [IntervalStep(name: "  ", seconds: 30), IntervalStep(name: " Jog ", seconds: 30), IntervalStep(name: "", seconds: 30)])
        XCTAssertEqual(w.stepName(at: 0), "Step 1")
        XCTAssertEqual(w.stepName(at: 1), "Jog")
        XCTAssertEqual(w.stepName(at: 2), "Step 3")
    }

    func testNextStepCopiesTheLastTwoLines() {
        var w = Workout(name: "W", kind: .tailored, steps: [])
        XCTAssertEqual(w.nextStep().name, "")
        XCTAssertEqual(w.nextStep().seconds, 60)
        w.steps = [IntervalStep(name: "Jog", seconds: 60), IntervalStep(name: "Walk", seconds: 120)]
        XCTAssertEqual(w.nextStep().name, "Jog")
        XCTAssertEqual(w.nextStep().seconds, 120)
    }

    func testSteppedLengths() {
        XCTAssertEqual(IntervalStep.stepped(30, up: true), 35)
        XCTAssertEqual(IntervalStep.stepped(60, up: true), 75)
        XCTAssertEqual(IntervalStep.stepped(300, up: true), 360)
        XCTAssertEqual(IntervalStep.stepped(60, up: false), 55)
        XCTAssertEqual(IntervalStep.stepped(120, up: false), 105)
        XCTAssertEqual(IntervalStep.stepped(360, up: false), 300)
        XCTAssertEqual(IntervalStep.stepped(5, up: false), 5)
        XCTAssertEqual(IntervalStep.stepped(3600, up: true), 3600)
        XCTAssertEqual(IntervalStep.lengths.first, 10)
        XCTAssertEqual(IntervalStep.lengths.last, 3600)
    }

    func testSpokenLengths() {
        XCTAssertEqual(SpokenLength.words(45), "45 seconds")
        XCTAssertEqual(SpokenLength.words(60), "1 minute")
        XCTAssertEqual(SpokenLength.words(120), "2 minutes")
        XCTAssertEqual(SpokenLength.words(90), "1 minute 30 seconds")
        XCTAssertEqual(SpokenLength.words(61), "1 minute 1 second")
        XCTAssertEqual(SpokenLength.words(1), "1 second")
    }

    func testTheStartCue() {
        XCTAssertEqual(TailoredCue.start(name: "Jog", seconds: 120, isLast: false), "Jog. 2 minutes.")
        XCTAssertEqual(TailoredCue.start(name: "Walk", seconds: 60, isLast: true), "Last step. Walk. 1 minute.")
    }

    func testNoticesFromTheGetReady() {
        let w = pyramid()
        let n = Plan.notices(phases: Plan.phases(for: w), index: 0, left: 5, name: "Pyramid")
        XCTAssertEqual(n.count, 11)
        XCTAssertEqual(n[0].after, 5)
        XCTAssertEqual(n[0].title, "Jog · 1:00")
        XCTAssertEqual(n[0].body, "Step 1 of 10 · Pyramid")
        XCTAssertEqual(n[10].after, 5 + 1080)
        XCTAssertEqual(n[10].title, "Workout complete")
        XCTAssertEqual(n[10].body, "Pyramid")
    }

    func testNoticesMidWayAndPastTheEnd() {
        let phases = Plan.phases(for: pyramid())
        // Index 3 is step 3 (index 0 is the get ready), 30 s to go: steps 4 to 10, then the end.
        let n = Plan.notices(phases: phases, index: 3, left: 30, name: "Pyramid")
        XCTAssertEqual(n.count, 8)
        XCTAssertEqual(n[0].after, 30)
        XCTAssertEqual(n[0].title, "Walk · 2:00")
        XCTAssertEqual(n[0].body, "Step 4 of 10 · Pyramid")
        XCTAssertEqual(n[7].title, "Workout complete")
        XCTAssertEqual(n[7].after, 30 + 840)
        XCTAssertEqual(Plan.notices(phases: phases, index: 11, left: 0, name: "Pyramid"), [])
    }

    func testTheRecordSaysHowManyStepsWereDone() {
        let phases = Plan.phases(for: pyramid())
        let t = Date(timeIntervalSince1970: 1_000_000)
        let r = SessionRecord.of(pyramid(), started: t, ended: t.addingTimeInterval(400), phasesDone: Array(phases[0...4]), finished: false)
        XCTAssertEqual(r?.detail, "4 of 10 steps")
        XCTAssertEqual(r?.completed, false)
        XCTAssertNil(SessionRecord.of(pyramid(), started: t, ended: t, phasesDone: [phases[0]], finished: false))
    }

    func testStepsSurviveTheFileAndAnOldFileHasNone() throws {
        let made = pyramid()
        let back = try WorkoutFile.decode(WorkoutFile.encode([made]))
        XCTAssertEqual(back.first?.steps, made.steps)
        XCTAssertEqual(back.first?.kind, .tailored)
        let old = #"{"version":1,"workouts":[{"id":"5B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Old","kind":"intervals","colour":"green"}]}"#
        let decoded = try WorkoutFile.decode(Data(old.utf8))
        XCTAssertEqual(decoded.first?.name, "Old")
        XCTAssertEqual(decoded.first?.steps, [])
    }

    func testAWholeRunThroughTheExampleFinishes() {
        var s = Session(phases: Plan.phases(for: pyramid()))
        let t = Date(timeIntervalSince1970: 1_000_000)
        s.start(at: t)
        XCTAssertFalse(s.isFinished)
        s.tick(at: t.addingTimeInterval(100_000))
        XCTAssertTrue(s.isFinished)
    }
}
