import XCTest
@testable import WorkoutCore

/// 3.0: the rules by which two devices' data are joined through iCloud. No disk, no iCloud — the
/// rules themselves.
final class Version30SyncTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    /// A small gym log: one gym, two machines, one visit with two sets.
    private func log() -> GymLog {
        var g = GymLog()
        g.ensureGym()
        let gym = g.gyms[0].id
        let press = Machine(gymID: gym, name: "Chest press")
        let row = Machine(gymID: gym, name: "Seated row")
        g.machines = [press, row]
        var visit = GymVisit(gymID: gym, date: t0, started: t0)
        visit.entries = [MachineEntry(machineID: press.id, sets: [GymSet(kg: 50, reps: 12), GymSet(kg: 50, reps: 10)])]
        g.visits = [visit]
        g.currentGymID = gym
        return g
    }

    /// A device: its gym log and the doc with marks, as the app keeps them.
    private struct Device {
        var log: GymLog
        var doc: SyncDoc

        init(_ log: GymLog, rank: Int) {
            self.log = log
            doc = GymFile.doc(log)!.baselined(rank: rank)
        }

        /// A change made by hand on this device at a given moment.
        mutating func change(at now: Date, _ edit: (inout GymLog) -> Void) {
            edit(&log)
            doc = GymFile.doc(log)!.stamped(after: doc, now: now)
        }

        /// Meets the iCloud file: both hold the joined data afterwards.
        mutating func meet(_ cloud: inout SyncDoc?) {
            let join = SyncJoin.join(.gym, local: doc, cloud: cloud.map { [$0] } ?? [], cloudFileThere: cloud != nil)
            if join.changesLocal {
                doc = join.doc
                log = GymFile.log(from: join.doc)
            }
            if join.changesCloud { cloud = join.doc }
        }
    }

    // MARK: The files

    func testAnOldFileStillReadsAndGetsNoMarksOfItsOwn() throws {
        let old = try GymFile.encode(log())                 // as 2.6 wrote it: no "sync"
        XCTAssertFalse(String(decoding: old, as: UTF8.self).contains("\"sync\""))
        let read = try SyncFile.gym.doc(from: old)
        XCTAssertFalse(read.hadMarks)
        XCTAssertTrue(read.doc.marks.changed.isEmpty)
        XCTAssertEqual(GymFile.log(from: read.doc).machines.map(\.name), ["Chest press", "Seated row"])
    }

    func testEveryFileSurvivesBeingTakenApartAndPutTogether() throws {
        let g = log()
        let doc = GymFile.doc(g)!.baselined(rank: 3)
        XCTAssertTrue(SyncFile.gym.holds(doc))
        let back = try SyncFile.gym.doc(from: SyncFile.gym.data(from: doc))
        XCTAssertTrue(back.hadMarks)
        XCTAssertEqual(back.doc, doc)
        XCTAssertEqual(try GymFile.encode(GymFile.log(from: doc)), try GymFile.encode(g))

        let workouts = Starters.all + [Workout(name: "Hill", kind: .tailored, steps: IntervalStep.example)]
        XCTAssertEqual(WorkoutFile.workouts(from: WorkoutFile.doc(workouts)!), workouts)

        let record = SessionRecord(workoutID: workouts[0].id, kind: .reps, name: "Push-ups", colour: "orange",
                                   started: t0, ended: at(600), completed: true, detail: "5 of 5 sets × 20 reps")
        XCTAssertEqual(HistoryFile.records(from: HistoryFile.doc([record])!), [record])

        let settings = SharedSettings(sounds: SoundChoice(restSound: .soft, buzz: .strong, spokenCountdown: false),
                                      presets: [IntervalPreset(name: "Mine", rounds: 6, workSeconds: 50, offSeconds: 10)])
        let sdoc = SettingsFile.doc(settings)!
        XCTAssertEqual(SettingsFile.settings(from: sdoc), settings)
        XCTAssertTrue(SyncFile.settings.holds(sdoc))
    }

    func testTwoRecordsWithOneIdAreNeverTakenApart() {
        var g = log()
        g.machines.append(g.machines[0])
        XCTAssertNil(GymFile.doc(g))
        XCTAssertThrowsError(try SyncFile.gym.doc(from: GymFile.encode(g))) { XCTAssertEqual($0 as? SyncFile.Problem, .notWhole) }
    }

    // MARK: A change on one device

    func testAChangeMarksOnlyWhatChanged() {
        var phone = Device(log(), rank: 3)
        let press = "machine/" + phone.log.machines[0].id.uuidString
        let row = "machine/" + phone.log.machines[1].id.uuidString
        phone.change(at: at(10)) { $0.machines[0].setting = "Seat 4" }
        XCTAssertEqual(phone.doc.marks.changed[press], at(10).timeIntervalSinceReferenceDate)
        XCTAssertEqual(phone.doc.marks.changed[row], SyncDoc.baseline(rank: 3))
        XCTAssertTrue(phone.doc.marks.gone.isEmpty)
    }

    func testDeletingLeavesADeletedMarkAndUndoBringsTheRecordBack() {
        var phone = Device(log(), rank: 3)
        let before = phone.log
        let row = "machine/" + phone.log.machines[1].id.uuidString
        phone.change(at: at(10)) { $0.machines.remove(at: 1) }
        XCTAssertEqual(phone.doc.marks.gone[row], at(10).timeIntervalSinceReferenceDate)
        XCTAssertNil(phone.doc.marks.changed[row])
        phone.change(at: at(14)) { $0 = before }                                    // Undo
        XCTAssertGreaterThan(phone.doc.marks.changed[row]!, phone.doc.marks.gone[row]!)
        var cloud: SyncDoc? = nil
        var mac = Device(GymLog(), rank: 1)
        phone.meet(&cloud); mac.meet(&cloud)
        XCTAssertEqual(mac.log.machines.map(\.name), ["Chest press", "Seated row"])
    }

    func testOnlyARealReorderMarksTheOrder() {
        var phone = Device(log(), rank: 3)
        let key = SyncDoc.orderKey("machine")
        phone.change(at: at(5)) { $0.machines.append(Machine(gymID: $0.gyms[0].id, name: "Leg press")) }
        XCTAssertEqual(phone.doc.marks.changed[key], SyncDoc.baseline(rank: 3), "adding is not re-ordering")
        phone.change(at: at(9)) { $0.machines.swapAt(0, 1) }
        XCTAssertEqual(phone.doc.marks.changed[key], at(9).timeIntervalSinceReferenceDate)
    }

    func testAMarkNeverGoesBackwardsWhenThisClockIsBehind() {
        var phone = Device(log(), rank: 3)
        let press = "machine/" + phone.log.machines[0].id.uuidString
        phone.doc.marks.changed[press] = at(1000).timeIntervalSinceReferenceDate    // came from a device whose clock is ahead
        phone.change(at: at(10)) { $0.machines[0].setting = "Seat 5" }
        XCTAssertGreaterThan(phone.doc.marks.changed[press]!, at(1000).timeIntervalSinceReferenceDate)
    }

    // MARK: Two devices

    func testASetLoggedOnThePhoneShowsOnTheMacAndBack() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        phone.meet(&cloud)
        var mac = Device(GymLog(), rank: 1)
        mac.meet(&cloud)
        XCTAssertEqual(mac.log.visits.first?.setCount, 2)

        phone.change(at: at(60)) { $0.visits[0].entries[0].sets.append(GymSet(kg: 52.5, reps: 8)) }
        phone.meet(&cloud); mac.meet(&cloud)
        XCTAssertEqual(mac.log.visits[0].entries[0].sets.map(\.kg), [50, 50, 52.5])

        mac.change(at: at(120)) { $0.machines[1].setting = "Pin 7" }
        mac.meet(&cloud); phone.meet(&cloud)
        XCTAssertEqual(phone.log.machines[1].setting, "Pin 7")
        XCTAssertEqual(phone.doc, mac.doc)
    }

    func testBothDevicesChangedOfflineBothKeepTheirChanges() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        phone.meet(&cloud)
        var pad = Device(GymLog(), rank: 2)
        pad.meet(&cloud)
        // Offline: the phone logs a set and adds a machine; the iPad renames another machine and adds a template.
        phone.change(at: at(60)) {
            $0.visits[0].entries[0].sets.append(GymSet(kg: 55, reps: 6))
            $0.machines.append(Machine(gymID: $0.gyms[0].id, name: "Leg press"))
        }
        pad.change(at: at(90)) {
            $0.machines[1].name = "Low row"
            $0.templates.append(PlanTemplate(name: "Push day", gymID: $0.gyms[0].id, order: [$0.machines[0].id]))
        }
        // Back online, in either order.
        pad.meet(&cloud); phone.meet(&cloud); pad.meet(&cloud)
        for d in [phone, pad] {
            XCTAssertEqual(d.log.machines.map(\.name), ["Chest press", "Low row", "Leg press"])
            XCTAssertEqual(d.log.visits[0].setCount, 3)
            XCTAssertEqual(d.log.templates.map(\.name), ["Push day"])
        }
        XCTAssertEqual(phone.doc, pad.doc)
    }

    func testTheSameRecordChangedOnBothTheNewerChangeStays() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        phone.meet(&cloud)
        var mac = Device(GymLog(), rank: 1)
        mac.meet(&cloud)
        phone.change(at: at(60)) { $0.machines[0].setting = "Seat 3 (phone, older)" }
        mac.change(at: at(90)) { $0.machines[0].setting = "Seat 5 (Mac, newer)" }
        phone.meet(&cloud); mac.meet(&cloud); phone.meet(&cloud)
        XCTAssertEqual(phone.log.machines[0].setting, "Seat 5 (Mac, newer)")
        XCTAssertEqual(mac.log.machines[0].setting, "Seat 5 (Mac, newer)")
    }

    func testDeletedOnOneDeviceGoesEverywhereUnlessItWasChangedLater() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        phone.meet(&cloud)
        var mac = Device(GymLog(), rank: 1)
        mac.meet(&cloud)
        // Deleted on the phone, untouched on the Mac: gone on both.
        phone.change(at: at(60)) { $0.machines.remove(at: 1) }
        phone.meet(&cloud); mac.meet(&cloud)
        XCTAssertEqual(mac.log.machines.map(\.name), ["Chest press"])
        // Deleted on the phone at 100, changed on the Mac at 130 (offline): the later change keeps it.
        phone.change(at: at(100)) { $0.machines.remove(at: 0) }
        mac.change(at: at(130)) { $0.machines[0].setting = "Seat 2" }
        phone.meet(&cloud); mac.meet(&cloud); phone.meet(&cloud)
        XCTAssertEqual(phone.log.machines.map(\.name), ["Chest press"])
        XCTAssertEqual(phone.log.machines[0].setting, "Seat 2")
    }

    func testAMissingOrEmptyICloudFileNeverEmptiesTheDevice() {
        let phone = Device(log(), rank: 3)
        // Nothing in iCloud yet.
        let first = SyncJoin.join(.gym, local: phone.doc, cloud: [], cloudFileThere: false)
        XCTAssertFalse(first.changesLocal)
        XCTAssertTrue(first.changesCloud)
        XCTAssertEqual(GymFile.log(from: first.doc).machines.count, 2)
        // An empty file there (a brand-new device wrote first): everything here stays and goes up.
        let empty = GymFile.doc(GymLog())!.baselined(rank: 2)
        let second = SyncJoin.join(.gym, local: phone.doc, cloud: [empty], cloudFileThere: true)
        XCTAssertEqual(GymFile.log(from: second.doc).machines.count, 2)
        XCTAssertEqual(GymFile.log(from: second.doc).visits.count, 1)
        XCTAssertTrue(second.changesCloud)
    }

    func testAConflictCopyIsJoinedInNotLost() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        phone.meet(&cloud)
        var mac = Device(GymLog(), rank: 1)
        mac.meet(&cloud)
        // Both write "the file" at the same moment: iCloud keeps the phone's and parks the Mac's as a conflict copy.
        phone.change(at: at(60)) { $0.machines[0].setting = "Seat 4" }
        mac.change(at: at(61)) { $0.machines.append(Machine(gymID: $0.gyms[0].id, name: "Leg curl")) }
        let join = SyncJoin.join(.gym, local: phone.doc, cloud: [phone.doc, mac.doc], cloudFileThere: true)
        let joined = GymFile.log(from: join.doc)
        XCTAssertEqual(joined.machines.map(\.name), ["Chest press", "Seated row", "Leg curl"])
        XCTAssertEqual(joined.machines[0].setting, "Seat 4")
        XCTAssertTrue(join.changesCloud, "the joined file replaces the file and its conflict copy")
    }

    func testJoiningIsTheSameEitherWayAndTwiceChangesNothing() {
        var a = Device(log(), rank: 3)
        var b = a
        b.doc = GymFile.doc(b.log)!.baselined(rank: 1)
        a.change(at: at(10)) { $0.machines[0].name = "Press" ; $0.machines.swapAt(0, 1) }
        b.change(at: at(20)) { $0.machines.append(Machine(gymID: $0.gyms[0].id, name: "Dips")); $0.rests = RestDefaults() ; $0.nudgeDays = 6 }
        let ab = SyncDoc.merged(a.doc, b.doc), ba = SyncDoc.merged(b.doc, a.doc)
        XCTAssertEqual(ab, ba)
        XCTAssertEqual(SyncDoc.merged(ab, a.doc), ab)
        XCTAssertEqual(SyncDoc.merged(ab, ab), ab)
        XCTAssertEqual(GymFile.log(from: ab).nudgeDays, 6)
        XCTAssertEqual(GymFile.log(from: ab).machines.map(\.name), ["Seated row", "Press", "Dips"])
        XCTAssertTrue(SyncFile.gym.holds(ab))
    }

    func testAFileFromANewerAppIsLeftAlone() {
        let phone = Device(log(), rank: 3)
        var newer = phone.doc
        newer.marks.format = SyncMarks.format + 1
        newer.records.removeAll()
        let join = SyncJoin.join(.gym, local: phone.doc, cloud: [newer], cloudFileThere: true)
        XCTAssertTrue(join.newerApp)
        XCTAssertFalse(join.changesLocal)
        XCTAssertFalse(join.changesCloud)
    }

    // MARK: Data from before 3.0

    func testFromBefore30TheIPhonesVersionOfTheSameRecordStays() {
        let shared = log()
        var onMac = shared
        onMac.machines[0].setting = "old, from a restore on the Mac"
        var onPhone = shared
        onPhone.machines[0].setting = "what the phone has"
        let joined = SyncDoc.merged(GymFile.doc(onMac)!.baselined(rank: 1), GymFile.doc(onPhone)!.baselined(rank: 3))
        XCTAssertEqual(GymFile.log(from: joined).machines[0].setting, "what the phone has")
    }

    func testTheMacsUntouchedStartersAndEmptyGymGoWhenThePhoneJoins() {
        // The Mac: three untouched starters and an empty "My gym". The phone: his real data.
        var macGym = GymLog(); macGym.ensureGym()
        let macWorkouts = WorkoutFile.doc(Starters.all)!.baselined(rank: 1)
        var phoneList = Starters.all
        phoneList[0].reps = 25                                   // he changed Push-ups long ago
        phoneList.append(Workout(name: "Hill", kind: .tailored, steps: IntervalStep.example))
        let phoneWorkouts = WorkoutFile.doc(phoneList)!.baselined(rank: 3)
        for cloud in [[macWorkouts], [phoneWorkouts]] {            // whoever joins first
            let local = cloud[0] == macWorkouts ? phoneWorkouts : macWorkouts
            let joined = SyncJoin.join(.workouts, local: local, cloud: cloud, cloudFileThere: true).doc
            XCTAssertEqual(WorkoutFile.workouts(from: joined).map(\.name), ["Push-ups", "Intervals", "Doctor's exercises", "Hill"])
            XCTAssertEqual(WorkoutFile.workouts(from: joined).first?.reps, 25)
        }
        let joinedGym = SyncJoin.join(.gym, local: GymFile.doc(macGym)!.baselined(rank: 1),
                                      cloud: [GymFile.doc(log())!.baselined(rank: 3)], cloudFileThere: true).doc
        let g = GymFile.log(from: joinedGym)
        XCTAssertEqual(g.gyms.count, 1)
        XCTAssertEqual(g.machines.count, 2)
        XCTAssertEqual(g.currentGymID, g.gyms[0].id)
    }

    func testOnOneDeviceStartersAndAnEmptyGymAreNeverTidiedAway() {
        var list = Starters.all
        list.append(Workout(name: "Hill", kind: .tailored, steps: IntervalStep.example))
        let doc = WorkoutFile.doc(list)!.baselined(rank: 3)
        XCTAssertEqual(WorkoutFile.workouts(from: WorkoutFile.tidy(doc)).count, 4)
        var g = log()
        g.gyms.append(GymPlace(name: GymLog.firstGymName))        // an empty second gym he keeps
        let gdoc = GymFile.doc(g)!.baselined(rank: 3)
        XCTAssertEqual(GymFile.log(from: GymFile.tidy(gdoc)).gyms.count, 2)
    }

    func testAMacGymThatWasUsedIsKept() {
        var macGym = log()
        macGym.machines[0].name = "Mac try-out"
        let joined = SyncJoin.join(.gym, local: GymFile.doc(macGym)!.baselined(rank: 1),
                                   cloud: [GymFile.doc(log())!.baselined(rank: 3)], cloudFileThere: true).doc
        let g = GymFile.log(from: joined)
        XCTAssertEqual(g.gyms.count, 2)
        XCTAssertEqual(g.machines.count, 4)
        XCTAssertEqual(g.visits.count, 2)
    }

    // MARK: Three devices, sounds and presets

    func testThreeDevicesEndUpAlike() {
        var cloud: SyncDoc? = nil
        var phone = Device(log(), rank: 3)
        var pad = Device(GymLog(), rank: 2)
        var mac = Device(GymLog(), rank: 1)
        for _ in 0..<2 { mac.meet(&cloud); phone.meet(&cloud); pad.meet(&cloud) }
        phone.change(at: at(10)) { $0.machines.append(Machine(gymID: $0.gyms[0].id, name: "A")) }
        pad.change(at: at(11)) { $0.homeIcon = "kettlebell" }
        mac.change(at: at(12)) { $0.machines.removeAll { $0.name == "Seated row" } }
        for _ in 0..<2 { phone.meet(&cloud); pad.meet(&cloud); mac.meet(&cloud) }
        XCTAssertEqual(phone.doc, pad.doc)
        XCTAssertEqual(pad.doc, mac.doc)
        XCTAssertEqual(phone.log.machines.map(\.name), ["Chest press", "A"])
        XCTAssertEqual(phone.log.homeIcon, "kettlebell")
        XCTAssertEqual(phone.log.gyms.count, 1)
    }

    func testSoundsAndPresetsTravel() {
        let quiet = SharedSettings(sounds: SoundChoice(restSound: .soft, buzz: .strong, spokenCountdown: false), presets: [])
        var phone = SettingsFile.doc(SharedSettings())!.baselined(rank: 3)
        let mac = SettingsFile.doc(SharedSettings())!.baselined(rank: 1)
        phone = SettingsFile.doc(quiet)!.stamped(after: phone, now: at(5))
        var withPreset = SharedSettings()
        withPreset.presets = [IntervalPreset(id: "mine-1", name: "Mine", rounds: 6, workSeconds: 50, offSeconds: 10)]
        let macNow = SettingsFile.doc(withPreset)!.stamped(after: mac, now: at(8))
        let joined = SettingsFile.settings(from: SyncDoc.merged(phone, macNow))
        XCTAssertFalse(joined.sounds.spokenCountdown)
        XCTAssertEqual(joined.presets.map(\.name), ["Mine"])
    }
}
