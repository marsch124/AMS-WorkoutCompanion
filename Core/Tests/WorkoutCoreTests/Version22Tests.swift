import XCTest
@testable import WorkoutCore

/// 2.2: a rest in Sets & reps or an interval workout speaks like a gym rest.
final class Version22Tests: XCTestCase {
    func testRestCuesInSetsAndIntervals() {
        let words = (1...90).reversed().compactMap { SpokenCue.word(secondsLeft: $0, phaseLength: 90, isWork: false) }
        XCTAssertEqual(words, ["Thirty seconds", "Twenty seconds", "Ten seconds", "Three", "Two", "One"])
        // A rest of 20 s: no "Twenty" right at its start, but "Ten seconds".
        XCTAssertNil(SpokenCue.word(secondsLeft: 20, phaseLength: 20, isWork: false))
        XCTAssertEqual(SpokenCue.word(secondsLeft: 10, phaseLength: 20, isWork: false), "Ten seconds")
        // Work rounds keep their own words.
        XCTAssertEqual(SpokenCue.word(secondsLeft: 10, phaseLength: 45, isWork: true), "Ten seconds")
    }
}
