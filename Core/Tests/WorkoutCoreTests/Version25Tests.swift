import XCTest
@testable import WorkoutCore

/// 2.5: a step carries pace, power, weight and level — the ones the workout uses.
final class Version25Tests: XCTestCase {
    func testPaceIsReadHoweverItIsTyped() {
        for typed in ["5:30", "5.30", "5,30", "530", " 5:30 "] {
            XCTAssertEqual(StepMeasure.pace.parse(typed), 330, typed)
        }
        XCTAssertEqual(StepMeasure.pace.parse("5"), 300)
        XCTAssertEqual(StepMeasure.pace.parse("5:3"), 330)
        XCTAssertEqual(StepMeasure.pace.parse("12:05"), 725)
        for nonsense in ["", "5:75", "abc", "0", "1:2:3"] {
            XCTAssertNil(StepMeasure.pace.parse(nonsense), nonsense)
        }
        XCTAssertEqual(StepMeasure.pace.text(330), "5:30")
        XCTAssertEqual(StepMeasure.pace.text(725), "12:05")
    }

    func testPowerWeightAndLevelAreRead() {
        XCTAssertEqual(StepMeasure.power.parse("150"), 150)
        XCTAssertNil(StepMeasure.power.parse("150.5"))
        XCTAssertEqual(StepMeasure.weight.parse("22,5"), 22.5)
        XCTAssertEqual(StepMeasure.weight.parse("20"), 20)
        XCTAssertEqual(StepMeasure.weight.text(22.5), "22.5")
        XCTAssertEqual(StepMeasure.weight.text(20), "20")
        XCTAssertEqual(StepMeasure.level.parse("8"), 8)
        XCTAssertNil(StepMeasure.level.parse("-1"))
    }

    func testShownAndSpokenWords() {
        XCTAssertEqual(StepMeasure.pace.shown(330), "5:30 /km")
        XCTAssertEqual(StepMeasure.power.shown(150), "150 W")
        XCTAssertEqual(StepMeasure.weight.shown(22.5), "22.5 kg")
        XCTAssertEqual(StepMeasure.level.shown(8), "Level 8")
        XCTAssertEqual(StepMeasure.pace.spoken(330), "5:30 per kilometre")
        XCTAssertEqual(StepMeasure.power.spoken(150), "150 watts")
        XCTAssertEqual(StepMeasure.weight.spoken(20), "20 kilos")
        XCTAssertEqual(StepMeasure.level.spoken(8), "Level 8")
    }

    private func hill() -> Workout {
        var jog = IntervalStep(name: "Jog", seconds: 120)
        jog.set(.pace, 330)
        jog.set(.power, 150)
        jog.set(.level, 8)
        var walk = IntervalStep(name: "Walk", seconds: 120)
        walk.set(.pace, 420)
        return Workout(name: "Hill", kind: .tailored, steps: [jog, walk], measures: [.power, .pace])
    }

    func testAStepShowsOnlyWhatTheWorkoutUsesInAFixedOrder() {
        var w = hill()
        XCTAssertEqual(w.shownMeasures, [.pace, .power])
        XCTAssertEqual(w.detail(at: 0), "5:30 /km \u{B7} 150 W")
        XCTAssertEqual(w.detail(at: 1), "7:00 /km")
        XCTAssertEqual(w.spokenDetail(at: 0), "5:30 per kilometre. 150 watts")
        // Turning a word off hides its numbers and keeps them; on again brings them back.
        w.toggle(.power)
        XCTAssertEqual(w.detail(at: 0), "5:30 /km")
        XCTAssertEqual(w.steps[0].value(.power), 150)
        w.toggle(.power)
        w.toggle(.level)
        XCTAssertEqual(w.detail(at: 0), "5:30 /km \u{B7} 150 W \u{B7} Level 8")
        w.measures = []
        XCTAssertNil(w.detail(at: 0))
        XCTAssertNil(w.detail(at: 9))
    }

    func testASpeedOrPowerTextOf24IsKeptAfterTheNumbers() {
        var w = hill()
        w.steps[1].target = "easy"
        XCTAssertEqual(w.detail(at: 1), "7:00 /km \u{B7} easy")
        XCTAssertEqual(w.spokenDetail(at: 1), "7:00 per kilometre. easy")
    }

    func testPlanVoiceAndNoticesCarryTheNumbers() {
        let w = hill()
        XCTAssertEqual(w.plan.first, PlanLine("1 \u{B7} Jog", "2:00 \u{B7} 5:30 /km \u{B7} 150 W"))
        XCTAssertEqual(TailoredCue.start(name: "Jog", seconds: 120, isLast: false, target: w.spokenDetail(at: 0)),
                       "Jog. 2 minutes. 5:30 per kilometre. 150 watts.")
        let notices = Plan.notices(phases: Plan.phases(for: w), index: 0, left: 5, name: "Hill",
                                   details: w.steps.indices.map { w.detail(at: $0) })
        XCTAssertEqual(notices.map(\.title), ["Jog \u{B7} 2:00 \u{B7} 5:30 /km \u{B7} 150 W", "Walk \u{B7} 2:00 \u{B7} 7:00 /km", "Workout complete"])
    }

    func testAddStepCopiesTheNumbersFromTwoLinesUp() {
        let next = hill().nextStep()
        XCTAssertEqual(next.name, "Jog")
        XCTAssertEqual(next.value(.pace), 330)
        XCTAssertEqual(next.value(.power), 150)
        XCTAssertEqual(next.seconds, 120)
    }

    func testNumbersSurviveTheFileAndAnOlderFileHasNone() throws {
        let made = hill()
        let back = try XCTUnwrap(WorkoutFile.decode(WorkoutFile.encode([made])).first)
        XCTAssertEqual(back.measures, [.power, .pace])
        XCTAssertEqual(back.steps, made.steps)
        let old = #"{"version":1,"workouts":[{"id":"5B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Old","kind":"tailored","colour":"violet","steps":[{"id":"6B0C2B6E-1A2B-4C3D-8E9F-0A1B2C3D4E5F","name":"Jog","seconds":90,"target":"8 km/h","easy":true}]}]}"#
        let w = try XCTUnwrap(WorkoutFile.decode(Data(old.utf8)).first)
        XCTAssertEqual(w.measures, [])
        XCTAssertEqual(w.steps[0].values, [:])
        // The old step was Easy in 2.4: since 2.6 its effort word stands first.
        XCTAssertEqual(w.detail(at: 0), "Easy \u{B7} 8 km/h")
    }
}
