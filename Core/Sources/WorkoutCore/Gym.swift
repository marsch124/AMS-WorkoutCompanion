import Foundation

/// One gym — each has its own machines (since 1.4).
public struct GymPlace: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// What a machine logs: weight and reps, time (treadmill, rowing machine) with level and incline,
/// or reps only (push-ups, sit-ups — an exercise without a machine, since 1.6).
public enum MachineLogs: String, Codable, CaseIterable, Sendable {
    case weights
    case time
    case reps
}

/// A muscle group a machine or exercise trains — for the statistics (since 1.9; yours to rename,
/// add, arrange, colour and delete since 1.10). The seven first groups keep their old names as ids
/// ("chest" …), so machines from 1.9 keep their group without any change to the file.
public struct MuscleGroup: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// Its colour in History and on a visit (an AMS-Icons colour key), the same everywhere.
    public var colour: String

    public init(id: String = UUID().uuidString, name: String, colour: String) {
        self.id = id
        self.name = name
        self.colour = colour
    }

    /// Time machines without a group count here, while it exists.
    public static let cardioID = "cardio"

    public static let defaults: [MuscleGroup] = [
        MuscleGroup(id: "chest", name: "Chest", colour: "red"),
        MuscleGroup(id: "back", name: "Back", colour: "blue"),
        MuscleGroup(id: "shoulders", name: "Shoulders", colour: "orange"),
        MuscleGroup(id: "arms", name: "Arms", colour: "pink"),
        MuscleGroup(id: "legs", name: "Legs", colour: "green"),
        MuscleGroup(id: "core", name: "Core", colour: "olive"),
        MuscleGroup(id: cardioID, name: "Cardio", colour: "violet"),
    ]

    /// The colours to choose from (AMS-Icons keys).
    public static let colours = ["red", "orange", "yellow", "olive", "green", "plum", "blue", "indigo", "violet", "pink", "brown", "slate"]
}

/// A machine or exercise at the gym, with its photo and how it is set up.
public struct Machine: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// The gym it stands in; nil only in files from before 1.4, until they are opened.
    public var gymID: UUID?
    public var name: String
    /// File name in the Photos folder.
    public var photo: String?
    /// How the machine is set up — "Seat 4, handles 2".
    public var setting: String
    /// Weight × reps (before 1.4 always), or time.
    public var logs: MachineLogs
    /// A photo of the machine's instruction plate, file name in the Photos folder (since 1.4).
    public var instructions: String?
    /// Since 1.5, each machine may set its own rest, weight step and reps rule; nil keeps the usual.
    public var restSeconds: Int?
    public var step: Double?
    public var topReps: Int?
    /// Time machines: a treadmill may have no level, a bike no incline (since 1.5; nil = has it).
    public var noLevel: Bool?
    public var noIncline: Bool?
    /// The hand-drawn icon shown when there is no photo (an AMS-Icons key, since 1.6); nil = the usual one.
    public var icon: String?
    /// What it trains (since 1.9); nil = not chosen yet. Time machines count as cardio when not chosen.
    /// A `MuscleGroup` id; nil = not chosen, or its group was deleted.
    public var muscle: String?
    /// A heavy machine rests longer by default (since 1.11, Settings → Rest); nil = a light machine.
    public var heavy: Bool?
    /// Superset partner (since 1.11): the machine done in turn with this one, with no rest in between.
    public var partner: UUID?

    public var isHeavy: Bool { heavy == true }

    public var hasLevel: Bool { noLevel != true }
    public var hasIncline: Bool { noIncline != true }

    /// The rest when the log's defaults are not at hand; use `GymLog.rest(for:)` on the screens.
    public var rest: Int { restSeconds ?? GymLog.restSeconds }
    public var weightStep: Double { step ?? GymLog.step }
    public var repsForMore: Int { topReps ?? GymLog.topReps }

    public init(id: UUID = UUID(), gymID: UUID? = nil, name: String = "", photo: String? = nil, setting: String = "",
                logs: MachineLogs = .weights, instructions: String? = nil,
                restSeconds: Int? = nil, step: Double? = nil, topReps: Int? = nil,
                hasLevel: Bool = true, hasIncline: Bool = true) {
        self.noLevel = hasLevel ? nil : true
        self.noIncline = hasIncline ? nil : true
        self.restSeconds = restSeconds
        self.step = step
        self.topReps = topReps
        self.id = id
        self.gymID = gymID
        self.name = name
        self.photo = photo
        self.setting = setting
        self.logs = logs
        self.instructions = instructions
    }

    enum CodingKeys: String, CodingKey { case id, gymID, name, photo, setting, logs, instructions, restSeconds, step, topReps, noLevel, noIncline, icon, muscle, heavy, partner }

    /// Files from before 1.4 have no gym, no `logs` and no instructions.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        gymID = try c.decodeIfPresent(UUID.self, forKey: .gymID)
        name = try c.decode(String.self, forKey: .name)
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
        setting = try c.decodeIfPresent(String.self, forKey: .setting) ?? ""
        logs = try c.decodeIfPresent(MachineLogs.self, forKey: .logs) ?? .weights
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds)
        step = try c.decodeIfPresent(Double.self, forKey: .step)
        topReps = try c.decodeIfPresent(Int.self, forKey: .topReps)
        noLevel = try c.decodeIfPresent(Bool.self, forKey: .noLevel)
        noIncline = try c.decodeIfPresent(Bool.self, forKey: .noIncline)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        // Anything odd reads as not chosen, never as a broken file.
        muscle = (try? c.decodeIfPresent(String.self, forKey: .muscle)) ?? nil
        heavy = (try? c.decodeIfPresent(Bool.self, forKey: .heavy)) ?? nil
        partner = (try? c.decodeIfPresent(UUID.self, forKey: .partner)) ?? nil
    }
}

/// One set: the weight in kilograms (0 = body weight) and the reps —
/// or, on a time machine, the time with its level and incline.
public struct GymSet: Codable, Hashable, Sendable {
    public var kg: Double
    public var reps: Int
    public var seconds: Int?
    public var level: Double?
    /// Per cent.
    public var incline: Double?
    /// A warm-up set (since 1.11): kept and shown, but never a record or a reason for more weight.
    public var warmup: Bool?
    /// When Set done was tapped (since 1.11.2); older sets have none.
    public var at: Date?

    public init(kg: Double, reps: Int, warmup: Bool = false) {
        self.kg = kg
        self.reps = reps
        self.warmup = warmup ? true : nil
    }

    public var isWarmup: Bool { warmup == true }

    /// A time set: no weight, no reps.
    public init(seconds: Int, level: Double?, incline: Double?) {
        self.kg = 0
        self.reps = 0
        self.seconds = seconds
        self.level = level
        self.incline = incline
    }

    public var isTime: Bool { seconds != nil }

    /// The same set whenever weight, reps, time, level, incline and warm-up match; when it was done does not count.
    public static func == (a: GymSet, b: GymSet) -> Bool {
        a.kg == b.kg && a.reps == b.reps && a.seconds == b.seconds && a.level == b.level
            && a.incline == b.incline && a.warmup == b.warmup
    }

    public func hash(into h: inout Hasher) {
        h.combine(kg); h.combine(reps); h.combine(seconds); h.combine(level); h.combine(incline); h.combine(warmup)
    }

    /// A new time machine's first go: 20 minutes, level 5, no incline.
    public static let starterTime = GymSet(seconds: 20 * 60, level: 5, incline: 0)

    /// "30 kg × 12", "Body weight × 12", "25 min · level 8 · incline 2.5 %".
    public var text: String {
        guard let seconds else { return "\(GymSet.weight(kg)) × \(reps)" }
        var parts = [GymSet.duration(seconds) + " min"]
        if let level { parts.append("level \(GymSet.number(level))") }
        if let incline, incline != 0 { parts.append("incline \(GymSet.number(incline)) %") }
        return parts.joined(separator: " · ")
    }

    /// 1500 → "25", 90 → "1:30".
    public static func duration(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60)" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "30 kg", "32.5 kg", "Body weight".
    public static func weight(_ kg: Double) -> String {
        if kg <= 0 { return "Body weight" }
        return "\(number(kg)) kg"
    }

    /// The iPhone's language and region: 32,5 in Sweden, the same as in the number boxes.
    nonisolated(unsafe) public static var locale = Locale.current

    /// 30 → "30", 32.5 → "32,5" (Sweden) or "32.5".
    public static func number(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }
}

/// The sets done on one machine during one visit.
public struct MachineEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var machineID: UUID
    public var sets: [GymSet]
    /// What to do next time, chosen after the sets (since 1.4).
    public var nextTime: GymSet?
    /// How it felt.
    public var note: String?

    public init(id: UUID = UUID(), machineID: UUID, sets: [GymSet] = []) {
        self.id = id
        self.machineID = machineID
        self.sets = sets
    }

    /// "30 kg × 12, 12, 10" when the weight stays the same; "30 × 12, 32.5 × 10" when it changes.
    public var text: String {
        guard let first = sets.first else { return "" }
        if sets.contains(where: \.isTime) { return sets.map(\.text).joined(separator: ", ") }
        if sets.allSatisfy({ $0.kg == first.kg }) {
            return "\(GymSet.weight(first.kg)) × " + sets.map { String($0.reps) }.joined(separator: ", ")
        }
        return sets.map { "\($0.kg <= 0 ? "BW" : GymSet.number($0.kg)) × \($0.reps)" }.joined(separator: ", ") + " kg"
    }

    /// The sets that count: every set but the warm-ups (all of them when there are only warm-ups).
    public var working: [GymSet] {
        let w = sets.filter { !$0.isWarmup }
        return w.isEmpty ? sets : w
    }

    public var heaviest: Double { working.map(\.kg).max() ?? 0 }

    /// The most reps in one set — the best of a reps-only exercise.
    public var mostReps: Int { working.map(\.reps).max() ?? 0 }

    /// "15, 15, 12 reps" — a reps-only exercise has no weight to show.
    public var repsText: String { sets.map { String($0.reps) }.joined(separator: ", ") + " reps" }
}

/// One trip to the gym: its date and the machines used, in the order they were used.
public struct GymVisit: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var gymID: UUID?
    public var date: Date
    public var entries: [MachineEntry]
    /// When the first set was done and when Finish was tapped.
    public var started: Date?
    public var finished: Date?
    /// A heading and notes, given after Finish (since 1.4).
    public var title: String?
    public var notes: String?
    /// The time typed by hand on the visit page (since 1.11.2); wins over the worked-out time.
    public var minutesByHand: Int?
    /// Photos of the session itself (since 1.13): file names in the Photos folder, in the order added.
    public var photos: [String]?

    public init(id: UUID = UUID(), gymID: UUID? = nil, date: Date, entries: [MachineEntry] = [],
                started: Date? = nil, finished: Date? = nil) {
        self.id = id
        self.gymID = gymID
        self.date = date
        self.entries = entries
        self.started = started
        self.finished = finished
    }

    public var setCount: Int { entries.reduce(0) { $0 + $1.sets.count } }

    /// Minutes logged on time machines.
    public var minutesOnMachines: Int {
        entries.flatMap(\.sets).reduce(0) { $0 + ($1.seconds ?? 0) } / 60
    }

    /// When the last set was done, for sets that know it (since 1.11.2).
    public var lastSetAt: Date? { entries.flatMap(\.sets).compactMap(\.at).max() }

    /// Finish counts only this long after the last set; a later Finish (at home, or tapped again) does not.
    public static let finishGrace: TimeInterval = 10 * 60
    /// An old visit (sets without times) longer than this was a forgotten Finish: no time is shown.
    public static let longestOldVisit: TimeInterval = 3 * 60 * 60

    /// Minutes from the first set to the last set — or to Finish, when tapped soon after the last set.
    public var minutes: Int? {
        if let minutesByHand { return minutesByHand }
        guard var started else { return nil }
        // A time set is saved when it ends: it began its own minutes earlier (1.13 — his 70 min bike
        // + 50 min treadmill showed 77 min, because the bike's 70 minutes came before "started").
        for set in entries.flatMap(\.sets) {
            if let at = set.at, let s = set.seconds, s > 0 { started = min(started, at.addingTimeInterval(-Double(s))) }
        }
        let end: Date
        if let last = lastSetAt {
            if let finished, finished >= last, finished <= last.addingTimeInterval(Self.finishGrace) {
                end = finished
            } else {
                end = last
            }
        } else {
            guard let finished, finished.timeIntervalSince(started) <= Self.longestOldVisit else { return nil }
            end = finished
        }
        // Never shorter than the minutes on time machines (sets typed in afterwards).
        return max(1, Int(end.timeIntervalSince(started) / 60), minutesOnMachines)
    }

    /// "Tuesday, 3 November 2026 · yesterday" — with the year, and today/yesterday when it is (since 1.11.3).
    public static func dateText(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        let text = date.formatted(style)
        if calendar.isDate(date, inSameDayAs: now) { return text + " · today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return text + " · yesterday" }
        return text
    }

    /// Everything lifted, in kilograms: weight × reps of every set.
    public var totalKg: Double {
        entries.reduce(0) { sum, e in sum + e.sets.reduce(0) { $0 + $1.kg * Double($1.reps) } }
    }
}

/// A machine someone else is on: come back to it later that day.
public struct BusyMark: Codable, Hashable, Sendable {
    public var machineID: UUID
    public var day: Date

    public init(machineID: UUID, day: Date) {
        self.machineID = machineID
        self.day = day
    }
}

/// Today's order of machines, planned before starting (since 1.4). Optional: without one, roam freely.
public struct DayPlan: Codable, Hashable, Sendable {
    public var day: Date
    public var gymID: UUID?
    public var order: [UUID]
    /// Left out today — out of order, or no time.
    public var skipped: [UUID]

    public init(day: Date, gymID: UUID?, order: [UUID], skipped: [UUID] = []) {
        self.day = day
        self.gymID = gymID
        self.order = order
        self.skipped = skipped
    }
}

/// What the gym screen offers for the next set.
public struct NextSet: Equatable, Sendable {
    public var set: GymSet
    /// Why — shown under the numbers, or nil when there is nothing to say.
    public var reason: String?
}

/// The usual rest after a set, by type (since 1.11). Each machine may still set its own.
public struct RestDefaults: Codable, Equatable, Hashable, Sendable {
    public var heavy: Int
    public var light: Int
    public var exercise: Int

    public init(heavy: Int = 120, light: Int = 90, exercise: Int = 60) {
        self.heavy = heavy
        self.light = light
        self.exercise = exercise
    }
}

/// One note found by Search my notes (since 1.11).
public struct NoteHit: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case machineNote, visitNote, setting }
    public var kind: Kind
    public var text: String
    /// The visit's day; nil for a machine's setting.
    public var date: Date?
    public var visitID: UUID?
    public var machineID: UUID?
    public var id: String { "\(kind.rawValue)-\(visitID?.uuidString ?? "")-\(machineID?.uuidString ?? "")" }
}

/// A plan saved under a name to use again (since 1.10) — "Leg day".
public struct PlanTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var gymID: UUID?
    public var order: [UUID]

    public init(id: UUID = UUID(), name: String, gymID: UUID?, order: [UUID]) {
        self.id = id
        self.name = name
        self.gymID = gymID
        self.order = order
    }
}

public struct GymLog: Codable, Equatable, Sendable {
    /// When every set last time reached this many reps, the next time suggests more weight.
    public static let topReps = 12
    /// The step of the weight buttons and of a suggestion, unless the machine has its own.
    public static let step = 2.5
    /// Rest between sets, before +15 s, unless the machine has its own.
    public static let restSeconds = 90
    /// A new machine's first set, before there is anything to go by.
    public static let starter = GymSet(kg: 20, reps: 10)
    /// A new reps-only exercise's first set: 10 reps, no weight.
    public static let starterReps = GymSet(kg: 0, reps: 10)

    public var machines: [Machine]
    public var visits: [GymVisit]
    /// Machines marked Busy, in the order they were marked.
    public var busyMarks: [BusyMark]
    public var gyms: [GymPlace]
    /// The gym chosen last; the gym screen opens there.
    public var currentGymID: UUID?
    /// Each gym's plan for its day (since 1.6; before, one plan for all gyms, so planning a second
    /// gym wiped the first gym's plan).
    public var plans: [DayPlan]
    /// The icon on the At the gym tile (an AMS-Icons key, since 1.6); nil = the usual one.
    public var homeIcon: String?
    /// The muscle groups, in your order (since 1.10; files without them get the seven defaults).
    public var muscles: [MuscleGroup]
    /// Saved plans to use again, each for its gym (since 1.10).
    public var templates: [PlanTemplate]
    /// The usual rest for heavy machines, light machines and exercises (since 1.11).
    public var rests: RestDefaults

    public init(machines: [Machine] = [], visits: [GymVisit] = [], busyMarks: [BusyMark] = [],
                gyms: [GymPlace] = [], currentGymID: UUID? = nil, plans: [DayPlan] = [], homeIcon: String? = nil,
                muscles: [MuscleGroup] = MuscleGroup.defaults, templates: [PlanTemplate] = [],
                rests: RestDefaults = RestDefaults()) {
        self.rests = rests
        self.muscles = muscles
        self.templates = templates
        self.machines = machines
        self.visits = visits
        self.busyMarks = busyMarks
        self.gyms = gyms
        self.currentGymID = currentGymID
        self.plans = plans
        self.homeIcon = homeIcon
    }

    /// The plan holding this machine (a machine stands in one gym, so in at most one plan).
    private func planIndex(with machineID: UUID) -> Int? {
        plans.firstIndex { $0.order.contains(machineID) || $0.skipped.contains(machineID) }
    }

    public func machine(_ id: UUID) -> Machine? { machines.first { $0.id == id } }

    /// The visit on this calendar day at this gym, if there is one.
    public func visit(on day: Date, gym: UUID? = nil, calendar: Calendar = .current) -> GymVisit? {
        visits.first { $0.gymID == gym && calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// The session still going on this day at this gym — not yet finished (since 1.12).
    /// After Finish there is none: the next set starts a second session that day.
    public func openVisit(on day: Date, gym: UUID? = nil, calendar: Calendar = .current) -> GymVisit? {
        visits.first { $0.gymID == gym && $0.finished == nil && calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Every session on this day at this gym, the earliest first.
    public func visits(on day: Date, gym: UUID? = nil, calendar: Calendar = .current) -> [GymVisit] {
        visits.filter { $0.gymID == gym && calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { ($0.started ?? $0.date) < ($1.started ?? $1.date) }
    }

    // MARK: Gyms

    public static let firstGymName = "My gym"

    /// The gym the screen shows: the one chosen last, else the first.
    public var currentGym: GymPlace? { gyms.first { $0.id == currentGymID } ?? gyms.first }

    public func machines(in gym: UUID?) -> [Machine] { machines.filter { $0.gymID == gym } }

    public func visits(in gym: UUID?) -> [GymVisit] { visitsNewestFirst.filter { $0.gymID == gym } }

    /// Before 1.4 there were no gyms: everything goes into one, "My gym", which can be renamed.
    public mutating func ensureGym() {
        if gyms.isEmpty { gyms = [GymPlace(name: GymLog.firstGymName)] }
        let first = gyms[0].id
        for i in machines.indices where machines[i].gymID == nil { machines[i].gymID = first }
        for i in visits.indices where visits[i].gymID == nil { visits[i].gymID = first }
        for i in plans.indices where plans[i].gymID == nil { plans[i].gymID = first }
        if currentGym?.id != currentGymID { currentGymID = currentGym?.id }
    }

    @discardableResult
    public mutating func addGym(_ name: String) -> UUID {
        let g = GymPlace(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        gyms.append(g)
        currentGymID = g.id
        return g.id
    }

    public mutating func renameGym(_ id: UUID, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = gyms.firstIndex(where: { $0.id == id }) else { return }
        gyms[i].name = n
    }

    // MARK: Today's plan

    /// Today's plan at this gym, if one was made.
    public func plan(on day: Date, gym: UUID?, calendar: Calendar = .current) -> DayPlan? {
        plans.first { $0.gymID == gym && calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// Repeat last visit (since 1.7): the machines of this gym's latest visit before `day`,
    /// in the order they were first used; machines deleted since then drop out.
    public func lastOrder(gym: UUID?, before day: Date, calendar: Calendar = .current) -> [UUID] {
        let start = calendar.startOfDay(for: day)
        guard let last = visits(in: gym).first(where: { $0.date < start && $0.setCount > 0 }) else { return [] }
        var order: [UUID] = []
        for e in last.entries where !e.sets.isEmpty && !order.contains(e.machineID) && machine(e.machineID) != nil {
            order.append(e.machineID)
        }
        return order
    }

    /// Sets this gym's plan; the other gyms keep theirs.
    public mutating func setPlan(_ order: [UUID], on day: Date, gym: UUID?) {
        plans.removeAll { $0.gymID == gym }
        if !order.isEmpty { plans.append(DayPlan(day: day, gymID: gym, order: order)) }
    }

    /// A planned machine counts as done once it has a set in today's visit.
    public func isDone(_ machineID: UUID, on day: Date, gym: UUID?, calendar: Calendar = .current) -> Bool {
        openVisit(on: day, gym: gym, calendar: calendar)?.entries.contains { $0.machineID == machineID && !$0.sets.isEmpty } ?? false
    }

    /// The next planned machine: not done today, not skipped and not busy.
    public func upNext(on day: Date, gym: UUID?, excluding current: UUID? = nil, calendar: Calendar = .current) -> UUID? {
        guard let p = plan(on: day, gym: gym, calendar: calendar) else { return nil }
        return p.order.first { id in
            id != current && !p.skipped.contains(id) && !isBusy(id, on: day, calendar: calendar)
                && !isDone(id, on: day, gym: gym, calendar: calendar)
        }
    }

    /// Moves a planned machine to the end, for later.
    public mutating func later(_ machineID: UUID) {
        guard let p = planIndex(with: machineID), plans[p].order.contains(machineID) else { return }
        plans[p].order.removeAll { $0 == machineID }
        plans[p].order.append(machineID)
    }

    /// Leaves a planned machine out today, or brings it back.
    public mutating func skip(_ machineID: UUID, _ on: Bool = true) {
        guard let p = planIndex(with: machineID) else { return }
        plans[p].skipped.removeAll { $0 == machineID }
        if on { plans[p].skipped.append(machineID) }
    }

    /// Puts another machine in a planned machine's place.
    public mutating func swap(_ machineID: UUID, for other: UUID) {
        guard let p = planIndex(with: machineID), let i = plans[p].order.firstIndex(of: machineID),
              !plans[p].order.contains(other) else { return }
        plans[p].order[i] = other
        plans[p].skipped.removeAll { $0 == machineID }
    }

    public mutating func removeFromPlan(_ machineID: UUID) {
        guard let p = planIndex(with: machineID) else { return }
        plans[p].order.removeAll { $0 == machineID }
        plans[p].skipped.removeAll { $0 == machineID }
        if plans[p].order.isEmpty { plans.remove(at: p) }
    }

    /// Visits, newest first.
    public var visitsNewestFirst: [GymVisit] {
        visits.sorted { ($0.date, $0.started ?? $0.date) > ($1.date, $1.started ?? $1.date) }
    }

    /// The most recent earlier visit's entry for this machine (visits other than `excluding`).
    public func last(_ machineID: UUID, excluding visitID: UUID? = nil) -> (visit: GymVisit, entry: MachineEntry)? {
        for v in visitsNewestFirst where v.id != visitID {
            if let e = v.entries.last(where: { $0.machineID == machineID && !$0.sets.isEmpty }) {
                return (v, e)
            }
        }
        return nil
    }

    /// A machine tile's line before it is used today: "Last: 35 kg", "Last: 12 reps", "Last: 25 min · level 8" or "New".
    /// Only sets of the machine's own kind count, so a machine switched to time never shows kilograms (since 1.11.3).
    public func lastText(_ m: Machine, excluding visitID: UUID? = nil) -> String {
        for v in visitsNewestFirst where v.id != visitID {
            for e in v.entries.reversed() where e.machineID == m.id {
                switch m.logs {
                case .time:
                    if let t = e.sets.first(where: \.isTime) { return "Last: \(t.text)" }
                case .reps:
                    let reps = e.working.filter { !$0.isTime }.map(\.reps).max() ?? 0
                    if reps > 0 { return "Last: \(reps) reps" }
                default:
                    let w = e.working.filter { !$0.isTime }
                    if !w.isEmpty { return "Last: \(GymSet.weight(w.map(\.kg).max() ?? 0))" }
                }
            }
        }
        return "New"
    }

    /// The heaviest weight ever done on this machine, leaving out one visit —
    /// on a reps-only exercise, the most reps in one set.
    public func best(_ machineID: UUID, excluding visitID: UUID? = nil) -> Double? {
        let sets = visits.filter { $0.id != visitID }
            .flatMap(\.entries).filter { $0.machineID == machineID }
            .flatMap(\.sets).filter { $0.reps > 0 && !$0.isWarmup }
        if machine(machineID)?.logs == .reps { return sets.map { Double($0.reps) }.max() }
        return sets.map(\.kg).max()
    }

    /// What counts as "better" on a machine: the weight, or the reps on a reps-only exercise.
    public func score(_ set: GymSet, machine machineID: UUID) -> Double {
        machine(machineID)?.logs == .reps ? Double(set.reps) : set.kg
    }

    /// One set, said the machine's way: "30 kg × 12" or "12 reps".
    public func text(_ set: GymSet, machine machineID: UUID) -> String {
        machine(machineID)?.logs == .reps ? "\(set.reps) reps" : set.text
    }

    /// One visit's entry, said the machine's way: "30 kg × 12, 10" or "15, 12 reps".
    public func text(_ entry: MachineEntry) -> String {
        machine(entry.machineID)?.logs == .reps ? entry.repsText : entry.text
    }

    /// The numbers to offer for the next set on a machine, in this visit:
    /// the set just done again; else the same set last time, with 2.5 kg more when every set last
    /// time reached 12 reps; else 20 kg × 10.
    public func next(_ machineID: UUID, in visit: GymVisit) -> NextSet {
        if var done = visit.entries.last(where: { $0.machineID == machineID })?.sets.last {
            done.warmup = nil
            return NextSet(set: done, reason: nil)
        }
        let isTime = machine(machineID)?.logs == .time
        let isReps = machine(machineID)?.logs == .reps
        guard let lastEntry = last(machineID, excluding: visit.id)?.entry, let first = lastEntry.working.first else {
            if isReps { return NextSet(set: GymLog.starterReps, reason: nil) }
            guard isTime, let m = machine(machineID) else { return NextSet(set: GymLog.starter, reason: nil) }
            return NextSet(set: GymSet(seconds: 20 * 60, level: m.hasLevel ? 5 : nil, incline: m.hasIncline ? 0 : nil), reason: nil)
        }
        if let planned = lastEntry.nextTime {
            return NextSet(set: planned, reason: "Your plan from last time: \(text(planned, machine: machineID))")
        }
        // Warm-ups never earn more weight: only the working sets count.
        let previous = lastEntry.working
        if isTime || first.isTime { return NextSet(set: first, reason: nil) }
        if isReps {
            // Every set reached the first set's reps: one more rep next time.
            guard previous.allSatisfy({ $0.reps >= first.reps }) else { return NextSet(set: first, reason: nil) }
            let up = first.reps + 1
            return NextSet(set: GymSet(kg: 0, reps: up),
                           reason: "Try \(up) reps — every set last time reached \(first.reps)")
        }
        let top = machine(machineID)?.repsForMore ?? GymLog.topReps
        if previous.allSatisfy({ $0.reps >= top }) {
            let up = first.kg + (machine(machineID)?.weightStep ?? GymLog.step)
            return NextSet(set: GymSet(kg: up, reps: max(1, top - 2)),
                           reason: "Try \(GymSet.weight(up)) — every set last time reached \(top) reps")
        }
        return NextSet(set: first, reason: nil)
    }

    /// The machines with a new heaviest weight in this visit.
    public func newBests(in visit: GymVisit) -> [UUID] {
        var seen: [UUID] = []
        for e in visit.entries where !seen.contains(e.machineID) {
            guard let before = best(e.machineID, excluding: visit.id) else { continue }
            if top(e.machineID, in: visit) > before { seen.append(e.machineID) }
        }
        return seen
    }

    /// The best of a visit on this machine: its heaviest weight, or most reps on a reps-only exercise.
    public func top(_ machineID: UUID, in visit: GymVisit) -> Double {
        let sets = visit.entries.filter { $0.machineID == machineID }.flatMap(\.sets).filter { !$0.isWarmup }
        return sets.map { score($0, machine: machineID) }.max() ?? 0
    }

    /// The heaviest weight (reps-only: most reps) of every visit on this machine, oldest first — for the little chart.
    public func history(_ machineID: UUID) -> [(date: Date, kg: Double, entry: MachineEntry)] {
        visits.sorted { $0.date < $1.date }.compactMap { v in
            let entries = v.entries.filter { $0.machineID == machineID && !$0.sets.isEmpty }
            let score: (MachineEntry) -> Double = { e in e.working.map { self.score($0, machine: machineID) }.max() ?? 0 }
            guard let top = entries.max(by: { score($0) < score($1) }) else { return nil }
            return (v.date, score(top), top)
        }
    }

    /// The machines marked Busy on this day, in the order they were marked.
    public func busy(on day: Date, calendar: Calendar = .current) -> [UUID] {
        busyMarks.filter { calendar.isDate($0.day, inSameDayAs: day) }.map(\.machineID)
    }

    public func isBusy(_ machineID: UUID, on day: Date, calendar: Calendar = .current) -> Bool {
        busy(on: day, calendar: calendar).contains(machineID)
    }

    // MARK: Changes

    /// Marks a machine Busy on a day, or takes the mark away. Marks from other days are dropped,
    /// so one forgotten at the gym never turns up next time.
    public mutating func setBusy(_ machineID: UUID, _ busy: Bool, on day: Date, calendar: Calendar = .current) {
        busyMarks.removeAll { !calendar.isDate($0.day, inSameDayAs: day) }
        let marked = isBusy(machineID, on: day, calendar: calendar)
        if busy && !marked { busyMarks.append(BusyMark(machineID: machineID, day: day)) }
        if !busy { busyMarks.removeAll { $0.machineID == machineID } }
    }

    /// Finish: the visit's end time; every Busy mark of that day and the day's plan go.
    public mutating func finish(visit visitID: UUID, at now: Date = Date(), calendar: Calendar = .current) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.finished = now
        put(v)
        busyMarks.removeAll { calendar.isDate($0.day, inSameDayAs: v.date) }
        plans.removeAll { $0.gymID == v.gymID && calendar.isDate($0.day, inSameDayAs: v.date) }
    }

    /// After the sets on a machine: what to do next time and how it felt; nil and empty words take them away.
    public mutating func nextTime(visit visitID: UUID, machine machineID: UUID, set: GymSet?, note: String) {
        guard var v = visits.first(where: { $0.id == visitID }),
              let e = v.entries.lastIndex(where: { $0.machineID == machineID }) else { return }
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        v.entries[e].nextTime = set
        v.entries[e].note = n.isEmpty ? nil : n
        put(v)
    }

    /// Sets a visit's time by hand; nil (or 0) goes back to the time worked out from the sets.
    public mutating func setMinutes(visit visitID: UUID, _ minutes: Int?) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.minutesByHand = (minutes ?? 0) > 0 ? minutes : nil
        put(v)
    }

    /// The heading and notes of a visit; empty words are kept as none.
    public mutating func describe(visit visitID: UUID, title: String, notes: String) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        v.title = t.isEmpty ? nil : t
        v.notes = n.isEmpty ? nil : n
        put(v)
    }

    /// Adds a set on a machine to the visit on `day`, making the visit and the entry when needed.
    /// A machine used again later in the same visit carries on in its entry.
    public mutating func add(_ set: GymSet, machine machineID: UUID, on day: Date, now: Date = Date(),
                             calendar: Calendar = .current) {
        let gym = machine(machineID)?.gymID
        // A finished session stays closed: a set after Finish starts the day's next session (since 1.12).
        var v = openVisit(on: day, gym: gym, calendar: calendar) ?? GymVisit(gymID: gym, date: day)
        if v.started == nil { v.started = now }
        var set = set
        set.at = now   // a prefilled set may carry last time's stamp
        if let i = v.entries.lastIndex(where: { $0.machineID == machineID }) {
            v.entries[i].sets.append(set)
        } else {
            v.entries.append(MachineEntry(machineID: machineID, sets: [set]))
        }
        put(v)
        setBusy(machineID, false, on: day, calendar: calendar)
    }

    /// Replaces or removes (`nil`) one set of a machine in a visit; an entry left empty goes.
    public mutating func change(visit visitID: UUID, machine machineID: UUID, set index: Int, to set: GymSet?) {
        guard var v = visits.first(where: { $0.id == visitID }),
              let e = v.entries.lastIndex(where: { $0.machineID == machineID }),
              v.entries[e].sets.indices.contains(index) else { return }
        if var set {
            if set.at == nil { set.at = v.entries[e].sets[index].at }
            v.entries[e].sets[index] = set
        } else { v.entries[e].sets.remove(at: index) }
        if v.entries[e].sets.isEmpty { v.entries.remove(at: e) }
        if v.entries.isEmpty { visits.removeAll { $0.id == visitID } } else { put(v) }
    }

    public mutating func put(_ visit: GymVisit) {
        if let i = visits.firstIndex(where: { $0.id == visit.id }) { visits[i] = visit } else { visits.append(visit) }
    }

    public mutating func save(_ machine: Machine) {
        var m = machine
        m.name = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
        m.setting = m.setting.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = machines.firstIndex(where: { $0.id == m.id }) { machines[i] = m } else { machines.append(m) }
    }

    /// Removes a machine and every set done on it.
    public mutating func delete(machine id: UUID) {
        machines.removeAll { $0.id == id }
        for i in visits.indices { visits[i].entries.removeAll { $0.machineID == id } }
        visits.removeAll { $0.entries.isEmpty }
        busyMarks.removeAll { $0.machineID == id }
        for i in machines.indices where machines[i].partner == id { machines[i].partner = nil }
        for i in templates.indices { templates[i].order.removeAll { $0 == id } }
        templates.removeAll { $0.order.isEmpty }
        removeFromPlan(id)
    }

    // MARK: Muscle groups (since 1.10)

    public func muscle(_ id: String?) -> MuscleGroup? { id.flatMap { id in muscles.first { $0.id == id } } }

    /// The group a machine counts for: its own, else Cardio for a time machine, else none.
    public func muscle(for machine: Machine?) -> MuscleGroup? {
        guard let machine else { return nil }
        return muscle(machine.muscle) ?? (machine.logs == .time ? muscle(MuscleGroup.cardioID) : nil)
    }

    /// Adds a group at the end (or saves changes to one); an empty name is not saved.
    public mutating func save(muscle group: MuscleGroup) {
        var g = group
        g.name = g.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.name.isEmpty else { return }
        if let i = muscles.firstIndex(where: { $0.id == g.id }) { muscles[i] = g } else { muscles.append(g) }
    }

    public mutating func moveMuscles(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { muscles[$0] }
        var rest = muscles.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let at = destination - source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: max(0, min(at, rest.count)))
        muscles = rest
    }

    /// Removes a group; its machines go back to "Not chosen". Their sets stay.
    public mutating func delete(muscle id: String) {
        muscles.removeAll { $0.id == id }
        for i in machines.indices where machines[i].muscle == id { machines[i].muscle = nil }
    }

    /// How many machines (in any gym) have this group.
    public func machineCount(muscle id: String) -> Int { machines.filter { $0.muscle == id }.count }

    // MARK: Plan templates (since 1.10)

    public func templates(gym: UUID?) -> [PlanTemplate] { templates.filter { $0.gymID == gym } }

    /// Saves the order as a template for the gym; the same name in that gym is replaced.
    @discardableResult
    public mutating func saveTemplate(named name: String, order: [UUID], gym: UUID?) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !order.isEmpty else { return nil }
        if let i = templates.firstIndex(where: { $0.gymID == gym && $0.name.caseInsensitiveCompare(n) == .orderedSame }) {
            templates[i].name = n
            templates[i].order = order
            return templates[i].id
        }
        let t = PlanTemplate(name: n, gymID: gym, order: order)
        templates.append(t)
        return t.id
    }

    /// A template's machines that still exist, in its order.
    public func order(of template: PlanTemplate) -> [UUID] { template.order.filter { machine($0) != nil } }

    public mutating func deleteTemplate(_ id: UUID) { templates.removeAll { $0.id == id } }

    // MARK: Rest per exercise type (since 1.11)

    /// The rest after a set: the machine's own, else the usual one for its type.
    public func rest(for machine: Machine?) -> Int {
        guard let machine else { return rests.light }
        if let own = machine.restSeconds { return own }
        if machine.logs == .reps { return rests.exercise }
        return machine.isHeavy ? rests.heavy : rests.light
    }

    // MARK: Supersets (since 1.11)

    /// Pairs two machines of one gym; their old partners are let go. Pairing a machine with itself
    /// or with nil takes its pair apart.
    public mutating func pair(_ a: UUID, with b: UUID?) {
        func letGo(_ id: UUID) {
            guard let i = machines.firstIndex(where: { $0.id == id }) else { return }
            if let p = machines[i].partner, let j = machines.firstIndex(where: { $0.id == p }), machines[j].partner == id {
                machines[j].partner = nil
            }
            machines[i].partner = nil
        }
        letGo(a)
        guard let b, b != a, machine(b) != nil, let i = machines.firstIndex(where: { $0.id == a }),
              let j = machines.firstIndex(where: { $0.id == b }) else { return }
        letGo(b)
        machines[i].partner = b
        machines[j].partner = a
    }

    /// The partner of a machine, while both still exist.
    public func partner(of machineID: UUID) -> Machine? {
        guard let p = machine(machineID)?.partner, let m = machine(p), m.partner == machineID else { return nil }
        return m
    }

    /// After a set in a superset: the partner to go to straight away, without rest, while it has done
    /// fewer sets today than this machine. nil = the round is complete: rest, then the partner again.
    public func supersetJump(after machineID: UUID, in visit: GymVisit?) -> UUID? {
        guard let p = partner(of: machineID), let visit else { return nil }
        func sets(_ id: UUID) -> Int { visit.entries.filter { $0.machineID == id }.reduce(0) { $0 + $1.sets.count } }
        return sets(p.id) < sets(machineID) ? p.id : nil
    }

    // MARK: Finding (since 1.11)

    /// The machines of a gym whose name or setting holds the words; empty words = all of them.
    public func machines(in gym: UUID?, matching words: String) -> [Machine] {
        let w = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return machines(in: gym) }
        return machines(in: gym).filter {
            $0.name.localizedStandardContains(w) || $0.setting.localizedStandardContains(w)
        }
    }

    /// Every note holding the words, newest first: the note on a machine in a visit (with its
    /// "next time"), a visit's title and notes, and a machine's setting.
    public func searchNotes(_ words: String) -> [NoteHit] {
        let w = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return [] }
        var hits: [NoteHit] = []
        for v in visitsNewestFirst {
            for e in v.entries {
                let next = e.nextTime.map { "Next time: " + text($0, machine: e.machineID) }
                let haystack = [e.note, next].compactMap { $0 }.joined(separator: " · ")
                if let note = e.note, note.localizedStandardContains(w) {
                    hits.append(NoteHit(kind: .machineNote, text: haystack, date: v.date, visitID: v.id, machineID: e.machineID))
                }
            }
            let visitText = [v.title, v.notes].compactMap { $0 }.joined(separator: " — ")
            if !visitText.isEmpty, visitText.localizedStandardContains(w) {
                hits.append(NoteHit(kind: .visitNote, text: visitText, date: v.date, visitID: v.id, machineID: nil))
            }
        }
        for m in machines where !m.setting.isEmpty && m.setting.localizedStandardContains(w) {
            hits.append(NoteHit(kind: .setting, text: m.setting, date: nil, visitID: nil, machineID: m.id))
        }
        return hits
    }

    /// Changes or removes (`nil`) one set of one entry of a visit — for fixing a visit afterwards
    /// (since 1.11). An entry left empty goes; a visit left empty goes too.
    public mutating func change(visit visitID: UUID, entry entryID: UUID, set index: Int, to set: GymSet?) {
        guard var v = visits.first(where: { $0.id == visitID }),
              let e = v.entries.firstIndex(where: { $0.id == entryID }),
              v.entries[e].sets.indices.contains(index) else { return }
        if let set { v.entries[e].sets[index] = set } else { v.entries[e].sets.remove(at: index) }
        if v.entries[e].sets.isEmpty { v.entries.remove(at: e) }
        if v.entries.isEmpty { visits.removeAll { $0.id == visitID } } else { put(v) }
    }

    public var photosInUse: Set<String> {
        Set(machines.compactMap(\.photo) + machines.compactMap(\.instructions) + visits.flatMap { $0.photos ?? [] })
    }

    /// Adds a photo of the session (since 1.13).
    public mutating func addPhoto(visit visitID: UUID, _ name: String) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.photos = (v.photos ?? []) + [name]
        put(v)
    }

    /// Takes a photo off the session; the file goes with the next tidy-up.
    public mutating func removePhoto(visit visitID: UUID, _ name: String) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.photos = (v.photos ?? []).filter { $0 != name }
        if v.photos?.isEmpty == true { v.photos = nil }
        put(v)
    }
}

/// `gym.json`: `{"version":1,"machines":[…],"visits":[…],"busy":[…],"gyms":[…],"currentGym":…,"plan":…}`
/// (`busy` since 1.3; `gyms`, `currentGym` and `plan` since 1.4 — older files have none and read as one gym).
public enum GymFile {
    struct Envelope: Codable {
        var version: Int
        var machines: [Machine]
        var visits: [GymVisit]
        var busy: [BusyMark]?
        var gyms: [GymPlace]?
        var currentGym: UUID?
        /// Before 1.6: one plan for all gyms.
        var plan: DayPlan?
        var plans: [DayPlan]?
        var homeIcon: String?
        var muscles: [MuscleGroup]?
        var templates: [PlanTemplate]?
        var rests: RestDefaults?
    }

    public static func encode(_ log: GymLog) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(Envelope(version: 1, machines: log.machines, visits: log.visits, busy: log.busyMarks,
                                        gyms: log.gyms, currentGym: log.currentGymID, plan: nil,
                                        plans: log.plans, homeIcon: log.homeIcon,
                                        muscles: log.muscles, templates: log.templates, rests: log.rests))
    }

    public static func decode(_ data: Data) throws -> GymLog {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let e = try dec.decode(Envelope.self, from: data)
        var log = GymLog(machines: e.machines, visits: e.visits, busyMarks: e.busy ?? [],
                         gyms: e.gyms ?? [], currentGymID: e.currentGym,
                         plans: e.plans ?? (e.plan.map { [$0] } ?? []), homeIcon: e.homeIcon,
                         muscles: e.muscles ?? MuscleGroup.defaults, templates: e.templates ?? [],
                         rests: e.rests ?? RestDefaults())
        log.ensureGym()
        return log
    }
}
