import XCTest
@testable import WorkoutCore

/// 1.29: a gym can have its own photo.
final class Version129Tests: XCTestCase {
    func testAGymKeepsItsPhotoAndThePhotoCountsAsInUse() throws {
        let id = UUID()
        var log = GymLog(gyms: [GymPlace(id: id, name: "City gym")], currentGymID: id)
        XCTAssertNil(log.gyms[0].photo)
        XCTAssertFalse(log.photosInUse.contains("gym.jpg"))

        log.setPhoto(gym: id, "gym.jpg")
        XCTAssertEqual(log.gyms[0].photo, "gym.jpg")
        XCTAssertTrue(log.photosInUse.contains("gym.jpg"), "the tidy-up must not take a gym's photo away")

        // It survives saving and reading, and a file from before 1.29 (no photo) still reads.
        let again = try JSONDecoder().decode(GymPlace.self, from: JSONEncoder().encode(log.gyms[0]))
        XCTAssertEqual(again.photo, "gym.jpg")
        let old = try JSONDecoder().decode(GymPlace.self, from: Data(#"{"id":"\#(id.uuidString)","name":"Old gym"}"#.utf8))
        XCTAssertNil(old.photo)
        XCTAssertEqual(old.name, "Old gym")

        log.setPhoto(gym: id, nil)
        XCTAssertFalse(log.photosInUse.contains("gym.jpg"))
        // An unknown gym changes nothing.
        log.setPhoto(gym: UUID(), "x.jpg")
        XCTAssertFalse(log.photosInUse.contains("x.jpg"))
    }
}
