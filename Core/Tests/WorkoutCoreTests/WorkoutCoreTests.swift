import XCTest
@testable import WorkoutCore

final class PlanTests: XCTestCase {
    func testSetsHaveARestBetweenThemButNotAfterTheLast() {
        let w = Workout(name: "Push-ups", kind: .reps, sets: 3, reps: 20, restSeconds: 60)
        XCTAssertEqual(Plan.phases(for: w), [
            .set(number: 1, of: 3, reps: 20),
            .rest(seconds: 60, nextSet: 2, of: 3),
            .set(number: 2, of: 3, reps: 20),
            .rest(seconds: 60, nextSet: 3, of: 3),
            .set(number: 3, of: 3, reps: 20),
        ])
    }

    func testNoRestTimeMeansNoRestPhases() {
        let w = Workout(kind: .reps, sets: 2, reps: 10, restSeconds: 0)
        XCTAssertEqual(Plan.phases(for: w), [.set(number: 1, of: 2, reps: 10), .set(number: 2, of: 2, reps: 10)])
    }

    func testIntervalsStartWithGetReady() {
        let w = Workout(kind: .intervals, rounds: 2, workSeconds: 40, offSeconds: 20)
        XCTAssertEqual(Plan.phases(for: w), [
            .getReady(seconds: 5),
            .work(seconds: 40, round: 1, of: 2),
            .off(seconds: 20, nextRound: 2, of: 2),
            .work(seconds: 40, round: 2, of: 2),
        ])
    }

    func testAnExerciseListHasNoClock() {
        XCTAssertTrue(Plan.phases(for: Workout(kind: .checklist)).isEmpty)
    }
}

final class SessionTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    func testASetWaitsForDone() {
        var s = Session(phases: Plan.phases(for: Workout(kind: .reps, sets: 2, reps: 5, restSeconds: 30)))
        s.start(at: t0)
        XCTAssertNil(s.remaining(at: t0))
        XCTAssertFalse(s.tick(at: t0 + 600), "a set never ends by itself")
        s.next(at: t0 + 600)
        XCTAssertEqual(s.current, .rest(seconds: 30, nextSet: 2, of: 2))
        XCTAssertEqual(s.remaining(at: t0 + 610), 20)
        XCTAssertTrue(s.tick(at: t0 + 630))
        XCTAssertEqual(s.current, .set(number: 2, of: 2, reps: 5))
        s.next(at: t0 + 700)
        XCTAssertTrue(s.isFinished)
    }

    func testTheClockCatchesUpAfterBeingAway() {
        var s = Session(phases: Plan.phases(for: Workout(kind: .intervals, rounds: 3, workSeconds: 40, offSeconds: 20)))
        s.start(at: t0)
        // get ready 5 + work 40 + off 20 = 65 s; 66 s in: one second into round 2.
        XCTAssertTrue(s.tick(at: t0 + 66))
        XCTAssertEqual(s.current, .work(seconds: 40, round: 2, of: 3))
        XCTAssertEqual(s.remaining(at: t0 + 66), 39)
        XCTAssertTrue(s.tick(at: t0 + 1_000))
        XCTAssertTrue(s.isFinished)
    }

    func testPauseKeepsTheTimeLeft() {
        var s = Session(phases: [.work(seconds: 40, round: 1, of: 1)])
        s.start(at: t0)
        s.pause(at: t0 + 10)
        XCTAssertFalse(s.tick(at: t0 + 500))
        XCTAssertEqual(s.remaining(at: t0 + 500), 30)
        s.resume(at: t0 + 500)
        XCTAssertEqual(s.remaining(at: t0 + 505), 25)
        s.addTime(15)
        XCTAssertEqual(s.remaining(at: t0 + 505), 40)
    }

    func testSkipLeavesAPausedPhaseRunning() {
        var s = Session(phases: [.rest(seconds: 30, nextSet: 2, of: 2), .work(seconds: 10, round: 1, of: 1)])
        s.start(at: t0)
        s.pause(at: t0 + 1)
        s.next(at: t0 + 2)
        XCTAssertFalse(s.isPaused)
        XCTAssertEqual(s.remaining(at: t0 + 2), 10)
    }

    func testFractionLeftRunsFromOneToZero() {
        var s = Session(phases: [.rest(seconds: 100, nextSet: 2, of: 2)])
        s.start(at: t0)
        XCTAssertEqual(s.fractionLeft(at: t0), 1)
        XCTAssertEqual(s.fractionLeft(at: t0 + 25), 0.75, accuracy: 0.0001)
    }
}

final class WorkoutTests: XCTestCase {
    func testSummaries() {
        XCTAssertEqual(Workout(kind: .reps, sets: 5, reps: 20, restSeconds: 90).summary, "5 × 20 · rest 1:30")
        XCTAssertEqual(Workout(kind: .reps, sets: 3, reps: 10, restSeconds: 0).summary, "3 × 10")
        XCTAssertEqual(Workout(kind: .intervals, rounds: 8, workSeconds: 40, offSeconds: 20).summary,
                       "8 × 0:40 work / 0:20 rest · 7:40")
        XCTAssertEqual(Workout(kind: .checklist).summary, "No exercises yet")
        XCTAssertEqual(Workout(kind: .checklist, exercises: [Exercise(name: "a")]).summary, "1 exercise")
    }

    func testClock() {
        XCTAssertEqual(Clock.text(5), "0:05")
        XCTAssertEqual(Clock.text(90), "1:30")
        XCTAssertEqual(Clock.text(3725), "1:02:05")
    }

    func testStarters() {
        XCTAssertEqual(Starters.all.map(\.name), ["Push-ups", "Intervals", "Doctor's exercises"])
        XCTAssertEqual(Starters.all.map(\.colour), ["orange", "green", "pink"])
    }

    func testTheFileRoundTrips() throws {
        let photo = Exercise(name: "Bridge", amount: "3 × 10", note: "Slowly", photo: "a.jpg")
        let list = Starters.all + [Workout(name: "Knee", kind: .checklist, colour: "navy", exercises: [photo])]
        XCTAssertEqual(try WorkoutFile.decode(WorkoutFile.encode(list)), list)
        XCTAssertEqual(WorkoutFile.photosInUse(list), ["a.jpg"])
    }

    func testAnOlderFileWithMissingFieldsStillOpens() throws {
        let json = #"{"version":1,"workouts":[{"name":"Old","kind":"intervals"}]}"#
        let w = try XCTUnwrap(WorkoutFile.decode(Data(json.utf8)).first)
        XCTAssertEqual(w.name, "Old")
        XCTAssertEqual(w.colour, "green")
        XCTAssertEqual(w.rounds, 8)
    }
}

final class PaletteTests: XCTestCase {
    func testSeventeenColoursTwoRowsNoTeal() {
        XCTAssertEqual(Palette.all.count, 17)
        XCTAssertEqual(Set(Palette.all.map(\.key)).count, 17)
        for s in Palette.all {
            let c = Palette.rgb(s.fill)
            let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
            guard mx - mn > 0.08 else { continue } // grey: no hue
            var h: Double
            if mx == c.r { h = 60 * ((c.g - c.b) / (mx - mn)) }
            else if mx == c.g { h = 60 * ((c.b - c.r) / (mx - mn) + 2) }
            else { h = 60 * ((c.r - c.g) / (mx - mn) + 4) }
            if h < 0 { h += 360 }
            XCTAssertFalse((160...200).contains(h), "\(s.name) is teal (hue \(h))")
        }
    }

    func testWordsOnEveryColourAreReadable() {
        for s in Palette.all {
            XCTAssertGreaterThanOrEqual(Palette.contrast(s.fill, s.ink), 3.0, s.name)
        }
    }

    func testUnknownKeyFallsBackToOrange() {
        XCTAssertEqual(Palette.swatch("teal").key, "orange")
    }
}
