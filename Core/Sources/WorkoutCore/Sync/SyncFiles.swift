import Foundation

/// The sound choices and his own interval presets (since 3.0 in `settings.json`, so they travel to
/// the other devices and sit in backups; before, in the phone's small settings store).
public struct SharedSettings: Codable, Equatable, Sendable {
    public var sounds: SoundChoice
    public var presets: [IntervalPreset]

    public init(sounds: SoundChoice = SoundChoice(), presets: [IntervalPreset] = []) {
        self.sounds = sounds
        self.presets = presets
    }
}

/// `settings.json`: `{"version":1,"sounds":{…},"presets":[…],"sync":{…}}`.
public enum SettingsFile {
    public static let name = "settings.json"

    struct Envelope: Codable {
        var version: Int
        var sounds: SoundChoice?
        var presets: [IntervalPreset]?
        var sync: SyncMarks?
    }

    public static func encode(_ s: SharedSettings, marks: SyncMarks? = nil) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(Envelope(version: 1, sounds: s.sounds, presets: s.presets, sync: marks))
    }

    public static func read(_ data: Data) throws -> (settings: SharedSettings, marks: SyncMarks?) {
        let e = try JSONDecoder().decode(Envelope.self, from: data)
        return (SharedSettings(sounds: e.sounds ?? SoundChoice(), presets: e.presets ?? []), e.sync)
    }

    public static func doc(_ s: SharedSettings) -> SyncDoc? {
        var b = DocBuilder()
        b.one("sounds", s.sounds)
        b.list("preset", s.presets) { $0.id }
        return b.whole ? b.doc : nil
    }

    public static func settings(from doc: SyncDoc) -> SharedSettings {
        let r = DocReader(doc)
        return SharedSettings(sounds: r.one("sounds", SoundChoice.self) ?? SoundChoice(),
                              presets: r.list("preset", IntervalPreset.self))
    }
}

// MARK: Workouts

extension WorkoutFile {
    public static let name = "workouts.json"

    public static func encode(_ workouts: [Workout], marks: SyncMarks?) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(Envelope(version: 1, workouts: workouts, sync: marks))
    }

    public static func read(_ data: Data) throws -> (workouts: [Workout], marks: SyncMarks?) {
        let e = try JSONDecoder().decode(Envelope.self, from: data)
        return (e.workouts, e.sync)
    }

    public static func doc(_ workouts: [Workout]) -> SyncDoc? {
        var b = DocBuilder()
        b.list("workout", workouts) { $0.id.uuidString }
        return b.whole ? b.doc : nil
    }

    public static func workouts(from doc: SyncDoc) -> [Workout] {
        DocReader(doc).list("workout", Workout.self)
    }

    /// True for a starter workout nobody touched (whatever its id).
    static func isUntouchedStarter(_ w: Workout) -> Bool {
        Starters.all.contains { s in
            var s = s
            s.id = w.id
            return s == w
        }
    }

    /// After joining: the starter workouts a second device made for itself, untouched since, go —
    /// when a device that counts more (iPhone over iPad over Mac) brought workouts of its own from
    /// before 3.0, or when two devices of one kind hold the same untouched starter. Nothing he
    /// made or changed is ever removed here.
    public static func tidy(_ doc: SyncDoc) -> SyncDoc {
        var out = doc
        let dec = SyncJSON.decoder()
        struct Item { let key: String; let w: Workout; let rank: Int?; let starter: Bool }
        let items: [Item] = (doc.orders["workout"] ?? []).compactMap { key in
            guard let data = doc.records[key], let w = try? dec.decode(Workout.self, from: data) else { return nil }
            let rank = SyncDoc.rank(doc.marks.changed[key])
            return Item(key: key, w: w, rank: rank, starter: rank != nil && isUntouchedStarter(w))
        }
        let top = items.compactMap(\.rank).max() ?? 0
        for item in items where item.starter {
            guard let rank = item.rank else { continue }
            let twin = items.contains { other in
                guard other.key != item.key, other.starter, other.rank == rank else { return false }
                var same = other.w
                same.id = item.w.id
                return same == item.w && other.key < item.key
            }
            if rank < top || twin { out.remove(item.key) }
        }
        return out
    }
}

extension SyncDoc {
    /// Takes a record out as "deleted just after it was last changed" — any later real change brings it back.
    mutating func remove(_ key: String) {
        guard records[key] != nil else { return }
        records[key] = nil
        marks.gone[key] = max((marks.changed[key] ?? 0) + 1, marks.gone[key] ?? 0)
        marks.changed[key] = nil
        if let list = key.split(separator: "/").first.map(String.init) {
            orders[list]?.removeAll { $0 == key }
        }
    }
}

// MARK: History

extension HistoryFile {
    public static let name = "history.json"

    public static func encode(_ records: [SessionRecord], marks: SyncMarks?) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(Envelope(version: 1, sessions: records, sync: marks))
    }

    public static func read(_ data: Data) throws -> (records: [SessionRecord], marks: SyncMarks?) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let e = try dec.decode(Envelope.self, from: data)
        return (e.sessions, e.sync)
    }

    public static func doc(_ records: [SessionRecord]) -> SyncDoc? {
        var b = DocBuilder()
        b.list("record", records) { $0.id.uuidString }
        return b.whole ? b.doc : nil
    }

    public static func records(from doc: SyncDoc) -> [SessionRecord] {
        DocReader(doc).list("record", SessionRecord.self)
    }
}

// MARK: Gym log

extension GymFile {
    public static let name = "gym.json"

    public static func read(_ data: Data) throws -> (log: GymLog, marks: SyncMarks?) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let e = try dec.decode(Envelope.self, from: data)
        return (try decode(data), e.sync)
    }

    private static func planKey(_ p: DayPlan) -> String { p.gymID?.uuidString ?? "none" }

    public static func doc(_ log: GymLog) -> SyncDoc? {
        var b = DocBuilder()
        b.list("machine", log.machines) { $0.id.uuidString }
        b.list("visit", log.visits) { $0.id.uuidString }
        b.list("gym", log.gyms) { $0.id.uuidString }
        b.list("muscle", log.muscles) { $0.id }
        b.list("template", log.templates) { $0.id.uuidString }
        b.list("plan", log.plans, id: planKey)
        b.list("busy", log.busyMarks) { $0.machineID.uuidString }
        b.list("carry", log.carried) { $0.machineID.uuidString }
        b.list("stretch", log.stretchBook?.custom ?? []) { $0.id }
        b.one("currentGym", log.currentGymID)
        b.one("homeIcon", log.homeIcon)
        b.one("rests", log.rests)
        b.one("arrived", log.arrived)
        b.one("nudgeDays", log.nudgeDays)
        b.one("stretchList", log.stretchID)
        b.one("book", log.stretchBook != nil)
        b.one("book.ticked", log.stretchBook?.ticked)
        b.one("book.holds", log.stretchBook?.holds)
        b.one("book.favourites", log.stretchBook?.favourites)
        b.one("book.warm", log.stretchBook?.warm)
        b.one("book.migratedFrom", log.stretchBook?.migratedFrom)
        return b.whole ? b.doc : nil
    }

    public static func log(from doc: SyncDoc) -> GymLog {
        let r = DocReader(doc)
        var log = GymLog(machines: r.list("machine", Machine.self), visits: r.list("visit", GymVisit.self),
                         busyMarks: r.list("busy", BusyMark.self), gyms: r.list("gym", GymPlace.self),
                         currentGymID: r.one("currentGym", UUID.self), plans: r.list("plan", DayPlan.self),
                         homeIcon: r.one("homeIcon", String.self), muscles: r.list("muscle", MuscleGroup.self),
                         templates: r.list("template", PlanTemplate.self),
                         rests: r.one("rests", RestDefaults.self) ?? RestDefaults(),
                         arrived: r.one("arrived", Arrival.self))
        log.carried = r.list("carry", Carry.self)
        log.nudgeDays = r.one("nudgeDays", Int.self)
        log.stretchID = r.one("stretchList", UUID.self)
        let custom = r.list("stretch", CustomStretch.self)
        if r.one("book", Bool.self) == true || !custom.isEmpty {
            var book = StretchBook()
            book.ticked = r.one("book.ticked", [String].self) ?? []
            book.holds = r.one("book.holds", [String: Int].self) ?? [:]
            book.favourites = r.one("book.favourites", [String].self) ?? []
            book.warm = r.one("book.warm", WarmPrefs.self)
            book.migratedFrom = r.one("book.migratedFrom", UUID.self)
            book.custom = custom
            log.stretchBook = book
        }
        return log
    }

    /// After joining: the empty "My gym" a second device made for itself goes, when a device that
    /// counts more brought a gym from before 3.0 (or two devices of one kind each made one). A gym
    /// with a machine, a visit, a template, hours, a photo or another name is never removed here.
    public static func tidy(_ doc: SyncDoc) -> SyncDoc {
        var out = doc
        let r = DocReader(doc)
        let gyms = r.list("gym", GymPlace.self)
        guard gyms.count > 1 else { return out }
        var used = Set<UUID>()
        for m in r.list("machine", Machine.self) { if let g = m.gymID { used.insert(g) } }
        for v in r.list("visit", GymVisit.self) { if let g = v.gymID { used.insert(g) } }
        for t in r.list("template", PlanTemplate.self) { if let g = t.gymID { used.insert(g) } }
        func key(_ g: GymPlace) -> String { "gym/" + g.id.uuidString }
        func rank(_ g: GymPlace) -> Int? { SyncDoc.rank(doc.marks.changed[key(g)]) }
        func empty(_ g: GymPlace) -> Bool {
            g.name == GymLog.firstGymName && g.hours == nil && g.photo == nil && !used.contains(g.id) && rank(g) != nil
        }
        let top = gyms.compactMap(rank).max() ?? 0
        var dropped: [GymPlace] = []
        for g in gyms where empty(g) {
            guard let mine = rank(g) else { continue }
            let twin = gyms.contains { $0.id != g.id && empty($0) && rank($0) == mine && key($0) < key(g) }
            if mine < top || twin { dropped.append(g) }
        }
        guard !dropped.isEmpty, dropped.count < gyms.count else { return out }
        for g in dropped {
            out.remove(key(g))
            out.remove("plan/" + g.id.uuidString)
        }
        // The chosen gym must still be there.
        let gone = Set(dropped.map(\.id))
        if let current = r.one("currentGym", UUID.self), gone.contains(current),
           let first = gyms.first(where: { !gone.contains($0.id) }),
           let data = try? SyncJSON.encoder().encode(One(v: first.id)) {
            out.records["one/currentGym"] = data
        }
        return out
    }
}

// MARK: The four files, alike

/// One of the data files that travel through iCloud, as bytes ⇄ SyncDoc.
public enum SyncFile: String, CaseIterable, Sendable {
    case workouts = "workouts.json"
    case gym = "gym.json"
    case history = "history.json"
    case settings = "settings.json"

    public enum Problem: Error, Equatable {
        /// Two records share one id: the file cannot be taken apart safely, so it is left alone.
        case notWhole
    }

    /// The file's bytes as a doc; a file from before 3.0 has no marks yet (`hadMarks` false).
    public func doc(from data: Data) throws -> (doc: SyncDoc, hadMarks: Bool) {
        let made: SyncDoc?
        let marks: SyncMarks?
        switch self {
        case .workouts: let f = try WorkoutFile.read(data); made = WorkoutFile.doc(f.workouts); marks = f.marks
        case .gym: let f = try GymFile.read(data); made = GymFile.doc(f.log); marks = f.marks
        case .history: let f = try HistoryFile.read(data); made = HistoryFile.doc(f.records); marks = f.marks
        case .settings: let f = try SettingsFile.read(data); made = SettingsFile.doc(f.settings); marks = f.marks
        }
        guard var doc = made else { throw Problem.notWhole }
        if let marks { doc.marks = marks }
        return (doc, marks != nil)
    }

    /// The doc as the file's bytes, marks included.
    public func data(from doc: SyncDoc) throws -> Data {
        switch self {
        case .workouts: return try WorkoutFile.encode(WorkoutFile.workouts(from: doc), marks: doc.marks)
        case .gym: return try GymFile.encode(GymFile.log(from: doc), marks: doc.marks)
        case .history: return try HistoryFile.encode(HistoryFile.records(from: doc), marks: doc.marks)
        case .settings: return try SettingsFile.encode(SettingsFile.settings(from: doc), marks: doc.marks)
        }
    }

    /// The clean-up after joining (see WorkoutFile.tidy and GymFile.tidy).
    public func tidy(_ doc: SyncDoc) -> SyncDoc {
        switch self {
        case .workouts: return WorkoutFile.tidy(doc)
        case .gym: return GymFile.tidy(doc)
        case .history, .settings: return doc
        }
    }

    /// True when the doc survives being written and read again unchanged — every record decodes.
    /// A doc that does not is never put in place of this device's data.
    public func holds(_ doc: SyncDoc) -> Bool {
        guard let data = try? data(from: doc), let back = try? self.doc(from: data) else { return false }
        return back.doc.records == doc.records && back.doc.orders == doc.orders
    }
}

/// What one meeting with iCloud comes to, for one file (since 3.0). Pure: no disk, no iCloud.
public struct SyncJoin: Equatable, Sendable {
    /// Everything joined; what this device and iCloud should both hold now.
    public var doc: SyncDoc
    /// This device's data differs from the joined data: put the joined data in place here.
    public var changesLocal: Bool
    /// The iCloud file differs (or is missing, or had conflict copies): write the joined data there.
    public var changesCloud: Bool
    /// The iCloud file comes from a newer app: nothing is written anywhere until this app is updated.
    public var newerApp: Bool

    /// `cloud` holds the iCloud file's doc first (if the file is there) and then every conflict copy.
    /// An empty `cloud` means "nothing there yet" — never "everything was deleted".
    public static func join(_ file: SyncFile, local: SyncDoc, cloud: [SyncDoc], cloudFileThere: Bool) -> SyncJoin {
        let mine = local.tidied
        if cloud.contains(where: { $0.marks.format > SyncMarks.format }) {
            return SyncJoin(doc: mine, changesLocal: false, changesCloud: false, newerApp: true)
        }
        let joined = file.tidy(SyncDoc.merged([mine] + cloud))
        let theirs = cloudFileThere ? cloud.first?.tidied : nil
        return SyncJoin(doc: joined, changesLocal: joined != mine,
                        changesCloud: theirs == nil || joined != theirs || cloud.count > 1, newerApp: false)
    }
}
