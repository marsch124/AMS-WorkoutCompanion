import XCTest
@testable import WorkoutCore

/// 1.21: Restore is all or nothing.
final class Version121Tests: XCTestCase {
    private func folder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Photos"), withIntermediateDirectories: true)
        try Data("old gym".utf8).write(to: dir.appendingPathComponent("gym.json"))
        try Data("old workouts".utf8).write(to: dir.appendingPathComponent("workouts.json"))
        try Data("old photo".utf8).write(to: dir.appendingPathComponent("Photos/old.jpg"))
        return dir
    }
    private func text(_ url: URL) -> String? { (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) } }

    func testRestorePutsTheBackupInPlace() throws {
        let dir = try folder()
        let backup = Backup(made: Date(), files: ["gym.json": Data("new gym".utf8)], photos: ["new.jpg": Data("new photo".utf8)])
        try backup.install(in: dir)
        XCTAssertEqual(text(dir.appendingPathComponent("gym.json")), "new gym")
        XCTAssertNil(text(dir.appendingPathComponent("workouts.json")), "a file the backup does not hold goes")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Photos").path), ["new.jpg"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(), ["Photos", "gym.json"], "no waiting folder is left")
    }

    func testAFailedRestoreLeavesEverythingAsItWas() throws {
        let dir = try folder()
        // A photo whose name is too long to be written: the restore fails on the way.
        let backup = Backup(made: Date(), files: ["gym.json": Data("new gym".utf8)],
                            photos: ["a.jpg": Data("x".utf8), String(repeating: "n", count: 400) + ".jpg": Data("x".utf8)])
        XCTAssertThrowsError(try backup.install(in: dir))
        XCTAssertEqual(text(dir.appendingPathComponent("gym.json")), "old gym")
        XCTAssertEqual(text(dir.appendingPathComponent("workouts.json")), "old workouts")
        XCTAssertEqual(text(dir.appendingPathComponent("Photos/old.jpg")), "old photo")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(), ["Photos", "gym.json", "workouts.json"])
    }
}
