import XCTest
@testable import WorkoutCore

/// 1.35: a rest says "Twenty seconds left", "Ten seconds left", then three-two-one.
final class Version135Tests: XCTestCase {
    func testRestCues() {
        let words = (1...90).compactMap { SpokenCue.word(secondsLeft: $0, phaseLength: 90, isWork: false) }
        XCTAssertEqual(words, ["One", "Two", "Three", "Ten seconds left", "Twenty seconds left"])
        // A rest of 20 s gets no "Twenty" at its start; one of 10 s no "Ten".
        XCTAssertNil(SpokenCue.word(secondsLeft: 20, phaseLength: 20, isWork: false))
        XCTAssertNil(SpokenCue.word(secondsLeft: 10, phaseLength: 10, isWork: false))
        // Work rounds keep their own words.
        XCTAssertEqual(SpokenCue.word(secondsLeft: 10, phaseLength: 45, isWork: true), "Ten seconds")
    }
}
