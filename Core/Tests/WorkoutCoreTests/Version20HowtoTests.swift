import XCTest
@testable import WorkoutCore

final class Version20HowtoTests: XCTestCase {
    func testRestMarks() {
        XCTAssertEqual(RestCuePlan.marks(restSeconds: 90), [30, 20, 10, 3, 2, 1])
        XCTAssertEqual(RestCuePlan.marks(restSeconds: 25), [20, 10, 3, 2, 1])
        XCTAssertEqual(RestCuePlan.marks(restSeconds: 12), [10, 3, 2, 1])
        XCTAssertEqual(RestCuePlan.marks(restSeconds: 5), [3, 2, 1])
        XCTAssertEqual(RestCuePlan.marks(restSeconds: 3), [])
    }

    func testDueSaysEachMarkOnce() {
        let marks = RestCuePlan.marks(restSeconds: 90)
        XCTAssertEqual(RestCuePlan.due(secondsLeft: 29.8, marks: marks, said: []), 30)
        XCTAssertNil(RestCuePlan.due(secondsLeft: 29.8, marks: marks, said: [30]))
        XCTAssertNil(RestCuePlan.due(secondsLeft: 45, marks: marks, said: []))
    }

    func testHowToSurvivesAndOldFilesRead() throws {
        var m = Machine(name: "Leg press")
        m.howTo = "Feet high, back flat."
        let back = try JSONDecoder().decode(Machine.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(back.howTo, "Feet high, back flat.")
        let old = #"{"id":"\#(UUID().uuidString)","name":"Old"}"#.data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(Machine.self, from: old).howTo)
    }

    func testSoftChimeIsDefaultOnlyWhenNeverChosen() throws {
        XCTAssertEqual(SoundChoice().restSound, .soft)
        XCTAssertEqual(try JSONDecoder().decode(SoundChoice.self, from: Data("{}".utf8)).restSound, .soft)
        XCTAssertEqual(try JSONDecoder().decode(SoundChoice.self, from: Data(#"{"restSound":"bell"}"#.utf8)).restSound, .bell)
    }
}
