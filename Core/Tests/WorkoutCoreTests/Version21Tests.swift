import XCTest
@testable import WorkoutCore

/// 2.1: warm-up moves that fit today's machines.
final class Version21Tests: XCTestCase {
    func testWarmupMovesFollowTodaysPlanOrTheLastVisitAndOnlyAdd() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date()).addingTimeInterval(10 * 3600)
        var log = GymLog()
        var row = Machine(name: "Row"); row.muscle = "back"
        var legs = Machine(name: "Leg press"); legs.muscle = "legs"
        var fly = Machine(name: "Fly"); fly.muscle = "shoulders"
        log.machines = [row, legs, fly]

        // Nothing planned, never been: nothing suggested, all ticked as in 2.0.
        XCTAssertEqual(log.suggestedWarmupMoves(gym: nil, on: today), .none)
        XCTAssertEqual(WarmPrefs.movesShown(saved: [], suggested: []).ticked.count, StretchLibrary.moves.count)

        // Last visit (yesterday) did the leg press → leg moves.
        log.add(GymSet(kg: 80, reps: 10), machine: legs.id, on: today.addingTimeInterval(-86400), calendar: cal)
        let fromLast = log.suggestedWarmupMoves(gym: nil, on: today)
        XCTAssertEqual(fromLast.words, "legs")
        XCTAssertTrue(fromLast.moves.contains("dyn-squat"))
        XCTAssertFalse(fromLast.moves.contains("dyn-arm-circles"))

        // Today's plan wins; a machine left out does not count.
        log.plans = [DayPlan(day: today, gymID: nil, order: [fly.id, row.id, legs.id], skipped: [legs.id])]
        let s = log.suggestedWarmupMoves(gym: nil, on: today)
        XCTAssertEqual(s.words, "shoulders, back")
        XCTAssertEqual(s.moves, ["dyn-arm-circles", "dyn-inchworm", "dyn-torso-turns", "dyn-worlds-greatest"])

        // His remembered ticks and order stay first; suggestions only add.
        let shown = WarmPrefs.movesShown(saved: ["dyn-squat", "dyn-inchworm"], suggested: s.moves)
        XCTAssertEqual(Array(shown.order.prefix(5)), ["dyn-squat", "dyn-inchworm", "dyn-arm-circles", "dyn-torso-turns", "dyn-worlds-greatest"])
        XCTAssertEqual(shown.ticked, Set(["dyn-squat", "dyn-inchworm", "dyn-arm-circles", "dyn-torso-turns", "dyn-worlds-greatest"]))
        XCTAssertEqual(shown.order.count, StretchLibrary.moves.count)
        // Nothing remembered: only the suggestions are ticked.
        XCTAssertEqual(WarmPrefs.movesShown(saved: [], suggested: s.moves).ticked, Set(s.moves))
    }
}
