import XCTest
@testable import WorkoutCore

/// 1.23: sound choices, spoken countdown words, interval presets.
final class Version123SoundTests: XCTestCase {
    func testSoundChoiceDecodesFromEmptyWithDefaults() throws {
        let c = try JSONDecoder().decode(SoundChoice.self, from: Data("{}".utf8))
        XCTAssertEqual(c, SoundChoice(restSound: .chime, buzz: .strong, spokenCountdown: true))
    }

    func testSpokenCueWords() {
        for s in 1...3 {
            XCTAssertNotNil(SpokenCue.word(secondsLeft: s, phaseLength: 10, isWork: false))
        }
        XCTAssertEqual(SpokenCue.word(secondsLeft: 3, phaseLength: 40, isWork: true), "Three")
        XCTAssertEqual(SpokenCue.word(secondsLeft: 20, phaseLength: 40, isWork: true), "Halfway")
        XCTAssertNil(SpokenCue.word(secondsLeft: 10, phaseLength: 20, isWork: false) )
        XCTAssertEqual(SpokenCue.word(secondsLeft: 10, phaseLength: 20, isWork: true), "Halfway")
        XCTAssertNil(SpokenCue.word(secondsLeft: 7, phaseLength: 15, isWork: true))
        XCTAssertNil(SpokenCue.word(secondsLeft: 5, phaseLength: 10, isWork: true))
        XCTAssertEqual(SpokenCue.word(secondsLeft: 10, phaseLength: 45, isWork: true), "Ten seconds")
        XCTAssertNil(SpokenCue.word(secondsLeft: 10, phaseLength: 25, isWork: true))
        XCTAssertNil(SpokenCue.word(secondsLeft: 20, phaseLength: 40, isWork: false))
    }

    func testBuiltInPresets() {
        XCTAssertEqual(IntervalPreset.builtIn.count, 5)
        XCTAssertEqual(IntervalPreset.builtIn[0].summary, "8 × 20 s / 10 s")
    }
}
