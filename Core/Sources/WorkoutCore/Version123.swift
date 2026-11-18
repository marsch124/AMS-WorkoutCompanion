import Foundation

// Everything new in 1.23: effort per set, pain flag, holds, move to the next visit, the clock that
// pauses, how the session felt, today against last visit, the stretch, the lock-screen session,
// the gym reminder and opening hours.

/// How a set felt (since 1.23).
public enum Effort: String, Codable, CaseIterable, Sendable {
    case easy, ok, hard
    public var title: String { self == .ok ? "OK" : rawValue.capitalized }
}

/// How a whole session felt, chosen after Finish (since 1.23).
public enum Feel: String, Codable, CaseIterable, Sendable {
    case great, good, ok, tired, rough
    public var title: String { self == .ok ? "OK" : rawValue.capitalized }
}

/// A machine moved to the next visit (since 1.23), and the day it was moved.
public struct Carry: Codable, Hashable, Sendable {
    public var machineID: UUID
    public var day: Date
    public init(machineID: UUID, day: Date) {
        self.machineID = machineID
        self.day = day
    }
}

/// One day's opening hours, in minutes after midnight: 6:00 = 360, 22:00 = 1320.
public struct DayHours: Codable, Hashable, Sendable {
    public var open: Int
    public var close: Int
    public init(open: Int, close: Int) {
        self.open = open
        self.close = close
    }
    /// "06:00"
    public static func text(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60) }
}

extension GymPlace {
    public static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// 0 = Monday … 6 = Sunday.
    static func dayIndex(_ date: Date, _ calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// "Open · closes 22:00", "Closes in 40 min", "Closed · opens 06:00", "Closed · opens Monday 06:00";
    /// nil when no hours are given.
    public func openLine(at now: Date, calendar: Calendar = .current) -> (text: String, open: Bool)? {
        guard let hours, hours.count == 7, hours.contains(where: { $0 != nil }) else { return nil }
        let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let today = Self.dayIndex(now, calendar)
        if let h = hours[today] {
            if minute >= h.open, minute < h.close {
                let left = h.close - minute
                return (left <= 60 ? "Closes in \(left) min" : "Open · closes \(DayHours.text(h.close))", true)
            }
            if minute < h.open { return ("Closed · opens \(DayHours.text(h.open))", false) }
        }
        for ahead in 1...7 {
            let i = (today + ahead) % 7
            if let h = hours[i] {
                let day = ahead == 1 ? "tomorrow" : Self.dayNames[i]
                return ("Closed · opens \(day) \(DayHours.text(h.open))", false)
            }
        }
        return nil
    }
}

extension Machine {
    /// A hold against the clock — a plank: logs time, with level and incline switched off (since 1.23).
    public var isHold: Bool { logs == .time && !hasLevel && !hasIncline }
}

/// One line of "today against last visit" on the Session done page.
public struct CompareLine: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// "18"
    public var now: String
    /// "+2", "−6 min", "same"
    public var change: String
    /// More than last time (time: neither good nor bad, so nil).
    public var better: Bool?
}

/// What the session shows on the lock screen (since 1.23).
public struct SessionCard: Codable, Hashable, Sendable {
    /// The clock counts up from here: the start, moved forward by every pause.
    public var start: Date
    public var gym: String
    /// "3 machines · 7 sets", or "No sets yet".
    public var line: String
    /// The machine in use or used last.
    public var machine: String?
    public var paused: Bool
    /// The clock's value while paused.
    public var seconds: Int
    /// When the clock will stand still unless a set comes first: 20 minutes after the last set.
    public var pauseAt: Date?

    public init(start: Date, gym: String, line: String, machine: String?, paused: Bool, seconds: Int, pauseAt: Date? = nil) {
        self.pauseAt = pauseAt
        self.start = start
        self.gym = gym
        self.line = line
        self.machine = machine
        self.paused = paused
        self.seconds = seconds
    }
}

extension GymVisit {
    /// With no set for this long the session clock stands still (since 1.23).
    public static let idleLimit: TimeInterval = 20 * 60

    /// The session clock: every stretch between two sets counts, but never more than 20 minutes
    /// (plus a time set's own length). Returns the seconds and whether the clock stands still now.
    public static func active(start: Date, sets: [GymSet], now: Date) -> (seconds: Int, paused: Bool) {
        var total: TimeInterval = 0
        var from = start
        for set in sets.filter({ $0.at != nil }).sorted(by: { $0.at! < $1.at! }) {
            guard let at = set.at, at > from else { continue }
            total += min(at.timeIntervalSince(from), idleLimit + Double(set.seconds ?? 0))
            from = at
        }
        let tail = max(0, now.timeIntervalSince(from))
        total += min(tail, idleLimit)
        return (Int(total), tail > idleLimit)
    }
}

extension GymLog {
    // MARK: Last time, set by set

    /// The working set in the same place last time — shown faintly beside the set you are about to do.
    /// `place` counts today's working sets so far. Time machines and a first time: none.
    public func lastSet(_ machineID: UUID, place: Int, excluding visitID: UUID?) -> GymSet? {
        guard machine(machineID)?.logs != .time, let before = last(machineID, excluding: visitID)?.entry.working,
              place >= 0, place < before.count, !before[place].isTime else { return nil }
        return before[place]
    }

    /// "Last time: 40 kg × 10 · hard"
    public func lastSetLine(_ machineID: UUID, place: Int, excluding visitID: UUID?) -> String? {
        guard let s = lastSet(machineID, place: place, excluding: visitID) else { return nil }
        return "Last time: \(text(s, machine: machineID))" + (s.effort.map { " · \($0.title.lowercased())" } ?? "")
    }

    // MARK: Effort and pain

    /// How one of today's sets felt; the same choice again takes it away.
    public mutating func effort(visit visitID: UUID, machine machineID: UUID, set index: Int, _ effort: Effort?) {
        guard var v = visits.first(where: { $0.id == visitID }),
              let e = v.entries.lastIndex(where: { $0.machineID == machineID }),
              v.entries[e].sets.indices.contains(index) else { return }
        v.entries[e].sets[index].effort = v.entries[e].sets[index].effort == effort ? nil : effort
        put(v)
    }

    /// Flags pain on a machine in a visit, or takes the flag away.
    public mutating func pain(visit visitID: UUID, machine machineID: UUID, _ on: Bool) {
        guard var v = visits.first(where: { $0.id == visitID }),
              let e = v.entries.lastIndex(where: { $0.machineID == machineID }) else { return }
        v.entries[e].pain = on ? true : nil
        put(v)
    }

    /// Pain was flagged on this machine the last time it was used.
    public func painLastTime(_ machineID: UUID, excluding visitID: UUID?) -> Bool {
        last(machineID, excluding: visitID)?.entry.pain == true
    }

    // MARK: Move to the next visit

    /// Leaves a machine out today and puts it first in line the next time at its gym.
    public mutating func moveToNextVisit(_ machineID: UUID, on day: Date) {
        skip(machineID)
        carried.removeAll { $0.machineID == machineID }
        carried.append(Carry(machineID: machineID, day: day))
    }

    /// Not next time either.
    public mutating func dropCarry(_ machineID: UUID) { carried.removeAll { $0.machineID == machineID } }

    /// The machines moved to this visit from an earlier day at this gym, in the order moved.
    public func carriedOver(gym: UUID?, on day: Date, calendar: Calendar = .current) -> [Machine] {
        let start = calendar.startOfDay(for: day)
        return carried.filter { $0.day < start }.compactMap { machine($0.machineID) }.filter { $0.gymID == gym }
    }

    /// Moved today, waiting for the next visit.
    public func isCarried(_ machineID: UUID) -> Bool { carried.contains { $0.machineID == machineID } }

    // MARK: The clock that pauses

    /// The session clock on this day at this gym: seconds, and whether it stands still.
    public func sessionClock(on day: Date, gym: UUID?, now: Date, calendar: Calendar = .current) -> (seconds: Int, paused: Bool)? {
        guard let start = sessionStart(on: day, gym: gym, calendar: calendar) else { return nil }
        let sets = openVisit(on: day, gym: gym, calendar: calendar)?.entries.flatMap(\.sets) ?? []
        return GymVisit.active(start: start, sets: sets, now: now)
    }

    // MARK: How it felt, and today against last visit

    public mutating func feel(visit visitID: UUID, _ feel: Feel?) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.feel = feel
        put(v)
    }

    /// The latest earlier session with sets at the same gym.
    public func previous(of visit: GymVisit) -> GymVisit? {
        let mine = visit.started ?? visit.date
        return visits(in: visit.gymID).first { $0.id != visit.id && $0.setCount > 0 && ($0.started ?? $0.date) < mine }
    }

    /// Machines, sets, time and kilograms of this session beside the one before; empty on a first visit.
    public func compare(_ visit: GymVisit) -> [CompareLine] {
        guard let before = previous(of: visit) else { return [] }
        func change(_ a: Double, _ b: Double, _ unit: String) -> String {
            let d = a - b
            if d == 0 { return "same" }
            return (d > 0 ? "+" : "−") + GymSet.number(abs(d)) + unit
        }
        var lines = [
            CompareLine(id: "machines", title: "Machines", now: "\(visit.performed.count)",
                        change: change(Double(visit.performed.count), Double(before.performed.count), ""),
                        better: visit.performed.count == before.performed.count ? nil : visit.performed.count > before.performed.count),
            CompareLine(id: "sets", title: "Sets", now: "\(visit.setCount)",
                        change: change(Double(visit.setCount), Double(before.setCount), ""),
                        better: visit.setCount == before.setCount ? nil : visit.setCount > before.setCount),
        ]
        if let a = visit.minutes, let b = before.minutes {
            lines.append(CompareLine(id: "time", title: "Time", now: "\(a) min", change: change(Double(a), Double(b), " min"), better: nil))
        }
        if visit.totalKg > 0 || before.totalKg > 0 {
            lines.append(CompareLine(id: "total", title: "Lifted in all", now: "\(GymSet.number(visit.totalKg)) kg",
                                     change: change(visit.totalKg, before.totalKg, " kg"),
                                     better: visit.totalKg == before.totalKg ? nil : visit.totalKg > before.totalKg))
        }
        return lines
    }

    // MARK: Lock screen

    /// The session going on this day at this gym, for the lock screen; nil when none is going.
    public func sessionCard(on day: Date, gym: UUID?, now: Date, calendar: Calendar = .current) -> SessionCard? {
        guard let clock = sessionClock(on: day, gym: gym, now: now, calendar: calendar) else { return nil }
        let visit = openVisit(on: day, gym: gym, calendar: calendar)
        let machines = visit?.performed.count ?? 0
        let sets = visit?.setCount ?? 0
        let line = sets == 0 ? "No sets yet"
            : "\(machines) machine\(machines == 1 ? "" : "s") · \(sets) set\(sets == 1 ? "" : "s")"
        let lastEntry = visit?.performed.max { ($0.sets.compactMap(\.at).max() ?? .distantPast) < ($1.sets.compactMap(\.at).max() ?? .distantPast) }
        return SessionCard(start: now.addingTimeInterval(-Double(clock.seconds)),
                           gym: gyms.first { $0.id == gym }?.name ?? GymLog.firstGymName,
                           line: line, machine: lastEntry.flatMap { machine($0.machineID)?.name },
                           paused: clock.paused, seconds: clock.seconds,
                           pauseAt: clock.paused ? nil : ((visit?.lastSetAt ?? sessionStart(on: day, gym: gym, calendar: calendar)) ?? now)
                               .addingTimeInterval(GymVisit.idleLimit))
    }

    // MARK: Gym reminder

    public static let usualNudgeDays = 4

    /// Days without a visit before the reminder; 0 = never.
    public var nudgeAfter: Int { nudgeDays ?? GymLog.usualNudgeDays }

    /// When to remind: 10:00 on the day that many days after the last visit with sets —
    /// nil when switched off, when there is no visit yet, or when that time has passed.
    public func nudgeDate(now: Date, calendar: Calendar = .current) -> Date? {
        guard nudgeAfter > 0, let last = visits.filter({ $0.setCount > 0 }).map(\.date).max(),
              let day = calendar.date(byAdding: .day, value: nudgeAfter, to: calendar.startOfDay(for: last)),
              let at = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day), at > now else { return nil }
        return at
    }

    // MARK: Opening hours

    public mutating func setHours(_ gymID: UUID, _ hours: [DayHours?]?) {
        guard let i = gyms.firstIndex(where: { $0.id == gymID }) else { return }
        let given = hours.map { $0.count == 7 && $0.contains { $0 != nil } } ?? false
        gyms[i].hours = given ? hours : nil
    }
}

extension Workout {
    /// The stretch offered after a gym session until you make your own (since 1.23): an ordinary
    /// exercise list, yours to change.
    public static func afterGymStretch() -> Workout {
        let each = "30 s each side"
        return Workout(name: "After-gym stretch", kind: .checklist, colour: "teal", exercises: [
            Exercise(name: "Chest in a doorway", amount: each, note: "Forearm on the frame, step through, chest forward."),
            Exercise(name: "Shoulder across the body", amount: each, note: "Pull the straight arm across the chest."),
            Exercise(name: "Hip flexor lunge", amount: each, note: "Back knee down, hips forward, body upright."),
            Exercise(name: "Hamstring", amount: each, note: "One leg straight in front, heel down, hinge at the hips."),
            Exercise(name: "Thigh, standing", amount: each, note: "Heel to the seat, knees together."),
            Exercise(name: "Child's pose", amount: "60 s", note: "Knees wide, arms long, breathe into the back."),
        ])
    }
}
