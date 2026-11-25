import XCTest
@testable import WorkoutCore

final class Version31NotesTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }
    private let now = Date(timeIntervalSince1970: 1_795_000_000)   // late Nov 2026
    private func note(_ id: String = "A", at: Date? = nil, effort: Int? = nil) -> TrainingNotes.Note {
        TrainingNotes.Note(id: id, title: "At the gym", minutes: 35, effort: effort, at: at ?? now)
    }
    private func json(_ d: Data?) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: d ?? Data())) as? [String: Any] ?? [:]
    }

    func testFirstNoteMakesTheItemWithAllFields() {
        let d = TrainingNotes.adding(note(), to: nil, now: now, calendar: cal)
        let root = json(d)
        XCTAssertEqual(root["format"] as? Int, 1)
        let done = root["done"] as? [[String: Any]]
        XCTAssertEqual(done?.count, 1)
        XCTAssertEqual(done?[0]["kind"] as? String, "strength")
        XCTAssertEqual(done?[0]["from"] as? String, "workouts")
        XCTAssertEqual(done?[0]["minutes"] as? Int, 35)
        XCTAssertEqual(done?[0]["title"] as? String, "At the gym")
        XCTAssertNil(done?[0]["effort"])
        XCTAssertTrue((done?[0]["at"] as? String)?.hasSuffix("Z") == true)
        XCTAssertEqual((done?[0]["day"] as? String)?.count, 10)
    }

    func testEffortOnlyWhenGiven() {
        let d = TrainingNotes.adding(note(effort: 6), to: nil, now: now, calendar: cal)
        XCTAssertEqual((json(d)["done"] as? [[String: Any]])?[0]["effort"] as? Int, 6)
    }

    func testOtherAppsNotesAndUnknownFieldsStay() {
        let old = #"{"format":1,"future":{"x":[1,2]},"feel":{"day":"2026-11-25","value":4,"from":"morning"},"done":[{"id":"M","day":"2026-11-25","kind":"stretch","minutes":12,"from":"morning","extra":true}]}"#
        let d = TrainingNotes.adding(note(), to: Data(old.utf8), now: now, calendar: cal)
        let root = json(d)
        XCTAssertNotNil(root["future"])
        XCTAssertEqual((root["feel"] as? [String: Any])?["value"] as? Int, 4)
        let done = root["done"] as? [[String: Any]]
        XCTAssertEqual(done?.count, 2)
        XCTAssertEqual(done?[0]["extra"] as? Bool, true)
    }

    func testNewerFormatIsNeitherReadNorWritten() {
        let d = Data(#"{"format":2,"done":[]}"#.utf8)
        XCTAssertNil(TrainingNotes.adding(note(), to: d, now: now, calendar: cal))
    }

    func testBytesThatAreNotNotesAreLeftAlone() {
        XCTAssertNil(TrainingNotes.adding(note(), to: Data("nonsense".utf8), now: now, calendar: cal))
        XCTAssertNil(TrainingNotes.adding(note(), to: Data("[1,2]".utf8), now: now, calendar: cal))
    }

    func testTheSameWorkoutIsNeverNotedTwice() {
        let once = TrainingNotes.adding(note("A"), to: nil, now: now, calendar: cal)
        XCTAssertNil(TrainingNotes.adding(note("A"), to: once, now: now, calendar: cal))
        let two = TrainingNotes.adding(note("B"), to: once, now: now, calendar: cal)
        XCTAssertEqual(TrainingNotes.doneIDs(in: two), ["A", "B"])
    }

    func testNotesOlderThanFourteenDaysGo() {
        let old = #"{"format":1,"done":[{"id":"OLD","day":"2026-10-01","kind":"stretch","from":"morning"},{"id":"EDGE","day":"2026-11-11","kind":"stretch","from":"morning"},{"id":"NODATE","kind":"routine"}]}"#
        let d = TrainingNotes.adding(note("NEW"), to: Data(old.utf8), now: now, calendar: cal)
        let ids = TrainingNotes.doneIDs(in: d)
        XCTAssertFalse(ids.contains("OLD"))
        XCTAssertTrue(ids.contains("NODATE"))
        XCTAssertTrue(ids.contains("NEW"))
    }

    func testFourteenDaysMeansTodayAndThe13Before() {
        let today = TrainingNotes.dayString(now, calendar: cal)
        let back13 = TrainingNotes.dayString(cal.date(byAdding: .day, value: -13, to: now)!, calendar: cal)
        let back14 = TrainingNotes.dayString(cal.date(byAdding: .day, value: -14, to: now)!, calendar: cal)
        let old = "{\"format\":1,\"done\":[{\"id\":\"K\",\"day\":\"\(back13)\"},{\"id\":\"G\",\"day\":\"\(back14)\"}]}"
        let ids = TrainingNotes.doneIDs(in: TrainingNotes.adding(note("T"), to: Data(old.utf8), now: now, calendar: cal))
        XCTAssertEqual(ids, ["K", "T"])
        XCTAssertEqual(today.count, 10)
    }

    func testRemovingAnUndoneNote() {
        let two = TrainingNotes.adding(note("B"), to: TrainingNotes.adding(note("A"), to: nil, now: now, calendar: cal), now: now, calendar: cal)
        let one = TrainingNotes.removing(id: "A", from: two)
        XCTAssertEqual(TrainingNotes.doneIDs(in: one), ["B"])
        XCTAssertNil(TrainingNotes.removing(id: "Z", from: two))
    }

    func testNotesForGymSessionsAndSetsAndRepsOnly() {
        let t = Date()
        var v = GymVisit(date: t, started: t, finished: t.addingTimeInterval(2400))
        v.minutesByHand = 40
        XCTAssertEqual(TrainingNotes.note(for: v)?.minutes, 40)
        XCTAssertEqual(TrainingNotes.note(for: v)?.id, v.id.uuidString)
        XCTAssertNil(TrainingNotes.note(for: GymVisit(date: t)))   // not finished
        let reps = SessionRecord(workoutID: nil, kind: .reps, name: "Push-ups", colour: "blue", started: t, ended: t.addingTimeInterval(600), completed: true, detail: "")
        XCTAssertEqual(TrainingNotes.note(for: reps)?.title, "Push-ups")
        var early = reps; early.completed = false
        XCTAssertNil(TrainingNotes.note(for: early))
        var cardio = reps; cardio.kind = .intervals
        XCTAssertNil(TrainingNotes.note(for: cardio))
    }
}
