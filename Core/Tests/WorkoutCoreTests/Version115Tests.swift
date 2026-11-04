import XCTest
@testable import WorkoutCore

/// Version 1.15: the rest on the lock screen and in the Dynamic Island.
final class Version115Tests: XCTestCase {
    let gym = UUID()

    func testRestCardNamesTheMachineAndTheNextSet() {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        let press = Machine(gymID: gym, name: "Leg press")
        l.save(press)
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: Date())
        l.add(GymSet(kg: 40, reps: 10), machine: press.id, on: Date())
        let visit = l.openVisit(on: Date(), gym: gym)!
        let start = Date()
        let card = l.restCard(machine: press.id, in: visit, start: start, end: start.addingTimeInterval(90))
        XCTAssertEqual(card.kind, .gym)
        XCTAssertEqual(card.title, "Leg press")
        XCTAssertEqual(card.next, "Set 3 · \(GymSet(kg: 40, reps: 10).text)")
        XCTAssertEqual(card.seconds, 90)
    }

    func testRestCardForRepsOnlyExercise() {
        var l = GymLog(gyms: [GymPlace(id: gym, name: "G")], currentGymID: gym)
        var push = Machine(gymID: gym, name: "Push-ups")
        push.logs = .reps
        l.save(push)
        l.add(GymSet(kg: 0, reps: 15), machine: push.id, on: Date())
        let visit = l.openVisit(on: Date(), gym: gym)!
        let card = l.restCard(machine: push.id, in: visit, start: Date(), end: Date().addingTimeInterval(60))
        XCTAssertEqual(card.next, "Set 2 · 15 reps")
    }

    func testRestCardTimeLeftAndProgress() {
        let start = Date(timeIntervalSince1970: 1000)
        let card = RestCard(kind: .workout, title: "Knees", next: "Set 2 of 3", start: start,
                            end: start.addingTimeInterval(60))
        XCTAssertEqual(card.left(at: start.addingTimeInterval(15)), 45, accuracy: 0.01)
        XCTAssertEqual(card.progress(at: start.addingTimeInterval(30)), 0.5, accuracy: 0.01)
        XCTAssertFalse(card.isOver(at: start.addingTimeInterval(59)))
        XCTAssertTrue(card.isOver(at: start.addingTimeInterval(61)))
        XCTAssertEqual(card.left(at: start.addingTimeInterval(200)), 0, "never below zero")
        XCTAssertEqual(card.progress(at: start.addingTimeInterval(200)), 1)
    }

    func testRestCardSurvivesSavingAndReading() throws {
        let card = RestCard(kind: .gym, title: "Row", next: "Set 2", start: Date(timeIntervalSince1970: 5),
                            end: Date(timeIntervalSince1970: 95))
        let back = try JSONDecoder().decode(RestCard.self, from: JSONEncoder().encode(card))
        XCTAssertEqual(back, card)
    }
}
