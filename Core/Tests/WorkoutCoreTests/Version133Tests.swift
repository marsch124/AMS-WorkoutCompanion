import XCTest
@testable import WorkoutCore

/// 1.33: weight and reps can be typed.
final class Version133Tests: XCTestCase {
    func testATypedNumberTakesACommaOrAPoint() {
        XCTAssertEqual(GymSet.typed("32,5"), 32.5)
        XCTAssertEqual(GymSet.typed(" 40.25 "), 40.25)
        XCTAssertEqual(GymSet.typed("12"), 12)
        XCTAssertNil(GymSet.typed(""))
        XCTAssertNil(GymSet.typed("abc"))
        XCTAssertNil(GymSet.typed("-5"))
        XCTAssertNil(GymSet.typed("20000"))
    }
}
