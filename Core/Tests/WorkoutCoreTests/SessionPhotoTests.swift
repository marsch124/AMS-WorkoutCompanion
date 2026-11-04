import XCTest
@testable import WorkoutCore

/// Version 1.13: photos of a session — kept, counted as in use (never tidied away), saved in gym.json.
final class SessionPhotoTests: XCTestCase {
    func testSessionPhotosAreKeptInUseAndSurviveSaving() throws {
        let gym = UUID()
        let press = Machine(gymID: gym, name: "Press", photo: "press.jpg")
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        l.save(press)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: Date())
        let v = l.visits[0].id
        l.addPhoto(visit: v, "a.jpg")
        l.addPhoto(visit: v, "b.jpg")
        XCTAssertEqual(l.visits[0].photos, ["a.jpg", "b.jpg"])
        XCTAssertEqual(l.photosInUse, ["press.jpg", "a.jpg", "b.jpg"])

        let back = try JSONDecoder().decode(GymLog.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back.visits[0].photos, ["a.jpg", "b.jpg"])

        l.removePhoto(visit: v, "a.jpg")
        XCTAssertEqual(l.visits[0].photos, ["b.jpg"])
        XCTAssertFalse(l.photosInUse.contains("a.jpg"))
        l.removePhoto(visit: v, "b.jpg")
        XCTAssertNil(l.visits[0].photos)
    }
}
