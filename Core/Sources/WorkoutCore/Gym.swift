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

/// The muscle group a machine or exercise trains — for the statistics (since 1.9).
public enum Muscle: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, arms, legs, core, cardio

    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
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
    public var muscle: Muscle?

    public var hasLevel: Bool { noLevel != true }
    public var hasIncline: Bool { noIncline != true }

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

    enum CodingKeys: String, CodingKey { case id, gymID, name, photo, setting, logs, instructions, restSeconds, step, topReps, noLevel, noIncline, icon, muscle }

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
        // An unknown muscle from a newer version reads as not chosen, never as a broken file.
        muscle = (try? c.decodeIfPresent(Muscle.self, forKey: .muscle)) ?? nil
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

    public init(kg: Double, reps: Int) {
        self.kg = kg
        self.reps = reps
    }

    /// A time set: no weight, no reps.
    public init(seconds: Int, level: Double?, incline: Double?) {
        self.kg = 0
        self.reps = 0
        self.seconds = seconds
        self.level = level
        self.incline = incline
    }

    public var isTime: Bool { seconds != nil }

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

    public var heaviest: Double { sets.map(\.kg).max() ?? 0 }

    /// The most reps in one set — the best of a reps-only exercise.
    public var mostReps: Int { sets.map(\.reps).max() ?? 0 }

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

    /// Minutes from the first set to Finish, when both are known.
    public var minutes: Int? {
        guard let started, let finished else { return nil }
        return max(1, Int(finished.timeIntervalSince(started) / 60))
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

/// Every machine and every visit — the whole gym log.
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

    public init(machines: [Machine] = [], visits: [GymVisit] = [], busyMarks: [BusyMark] = [],
                gyms: [GymPlace] = [], currentGymID: UUID? = nil, plans: [DayPlan] = [], homeIcon: String? = nil) {
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
        visit(on: day, gym: gym, calendar: calendar)?.entries.contains { $0.machineID == machineID && !$0.sets.isEmpty } ?? false
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
    public var visitsNewestFirst: [GymVisit] { visits.sorted { $0.date > $1.date } }

    /// The most recent earlier visit's entry for this machine (visits other than `excluding`).
    public func last(_ machineID: UUID, excluding visitID: UUID? = nil) -> (visit: GymVisit, entry: MachineEntry)? {
        for v in visitsNewestFirst where v.id != visitID {
            if let e = v.entries.last(where: { $0.machineID == machineID && !$0.sets.isEmpty }) {
                return (v, e)
            }
        }
        return nil
    }

    /// The heaviest weight ever done on this machine, leaving out one visit —
    /// on a reps-only exercise, the most reps in one set.
    public func best(_ machineID: UUID, excluding visitID: UUID? = nil) -> Double? {
        let sets = visits.filter { $0.id != visitID }
            .flatMap(\.entries).filter { $0.machineID == machineID }
            .flatMap(\.sets).filter { $0.reps > 0 }
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
        if let done = visit.entries.last(where: { $0.machineID == machineID })?.sets.last {
            return NextSet(set: done, reason: nil)
        }
        let isTime = machine(machineID)?.logs == .time
        let isReps = machine(machineID)?.logs == .reps
        guard let lastEntry = last(machineID, excluding: visit.id)?.entry, let first = lastEntry.sets.first else {
            if isReps { return NextSet(set: GymLog.starterReps, reason: nil) }
            guard isTime, let m = machine(machineID) else { return NextSet(set: GymLog.starter, reason: nil) }
            return NextSet(set: GymSet(seconds: 20 * 60, level: m.hasLevel ? 5 : nil, incline: m.hasIncline ? 0 : nil), reason: nil)
        }
        if let planned = lastEntry.nextTime {
            return NextSet(set: planned, reason: "Your plan from last time: \(text(planned, machine: machineID))")
        }
        let previous = lastEntry.sets
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
        let sets = visit.entries.filter { $0.machineID == machineID }.flatMap(\.sets)
        return sets.map { score($0, machine: machineID) }.max() ?? 0
    }

    /// The heaviest weight (reps-only: most reps) of every visit on this machine, oldest first — for the little chart.
    public func history(_ machineID: UUID) -> [(date: Date, kg: Double, entry: MachineEntry)] {
        visits.sorted { $0.date < $1.date }.compactMap { v in
            let entries = v.entries.filter { $0.machineID == machineID && !$0.sets.isEmpty }
            let score: (MachineEntry) -> Double = { e in e.sets.map { self.score($0, machine: machineID) }.max() ?? 0 }
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
        var v = visit(on: day, gym: gym, calendar: calendar) ?? GymVisit(gymID: gym, date: day)
        if v.started == nil { v.started = now }
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
        if let set { v.entries[e].sets[index] = set } else { v.entries[e].sets.remove(at: index) }
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
        removeFromPlan(id)
    }

    public var photosInUse: Set<String> { Set(machines.compactMap(\.photo) + machines.compactMap(\.instructions)) }
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
    }

    public static func encode(_ log: GymLog) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(Envelope(version: 1, machines: log.machines, visits: log.visits, busy: log.busyMarks,
                                        gyms: log.gyms, currentGym: log.currentGymID, plan: nil,
                                        plans: log.plans, homeIcon: log.homeIcon))
    }

    public static func decode(_ data: Data) throws -> GymLog {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let e = try dec.decode(Envelope.self, from: data)
        var log = GymLog(machines: e.machines, visits: e.visits, busyMarks: e.busy ?? [],
                         gyms: e.gyms ?? [], currentGymID: e.currentGym,
                         plans: e.plans ?? (e.plan.map { [$0] } ?? []), homeIcon: e.homeIcon)
        log.ensureGym()
        return log
    }
}
