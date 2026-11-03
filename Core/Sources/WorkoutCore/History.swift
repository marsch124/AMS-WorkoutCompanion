import Foundation

/// One Sets & reps, Interval or Exercise-list workout that was done (since 1.4).
/// Gym visits are not copied here: History reads them from the gym log.
public struct SessionRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var workoutID: UUID?
    public var kind: WorkoutKind
    /// The workout's name and colour key when it was done, so a later rename or delete keeps the record.
    public var name: String
    public var colour: String
    public var started: Date
    public var ended: Date
    /// False when the workout was ended before the last set, round or exercise.
    public var completed: Bool
    /// "5 of 5 sets × 20 reps", "6 of 8 rounds", "3 of 4 exercises".
    public var detail: String
    public var title: String?
    public var notes: String?

    public init(id: UUID = UUID(), workoutID: UUID?, kind: WorkoutKind, name: String, colour: String,
                started: Date, ended: Date, completed: Bool, detail: String, title: String? = nil, notes: String? = nil) {
        self.id = id
        self.workoutID = workoutID
        self.kind = kind
        self.name = name
        self.colour = colour
        self.started = started
        self.ended = ended
        self.completed = completed
        self.detail = detail
        self.title = title
        self.notes = notes
    }

    /// The record of a workout run: how far it got, from the phases done.
    public static func of(_ w: Workout, started: Date, ended: Date, phasesDone: [Phase], finished: Bool) -> SessionRecord? {
        let detail: String
        switch w.kind {
        case .reps:
            let n = phasesDone.filter { if case .set = $0 { return true } else { return false } }.count
            guard n > 0 else { return nil }
            detail = "\(n) of \(w.sets) sets × \(w.reps) reps"
        case .intervals:
            let n = phasesDone.filter { if case .work = $0 { return true } else { return false } }.count
            guard n > 0 else { return nil }
            detail = "\(n) of \(w.rounds) rounds"
        case .checklist:
            return nil
        }
        return SessionRecord(workoutID: w.id, kind: w.kind, name: w.name, colour: w.colour,
                             started: started, ended: ended, completed: finished, detail: detail)
    }

    /// The record of an exercise list: how many were ticked off.
    public static func of(_ w: Workout, started: Date, ended: Date, ticked: Int) -> SessionRecord? {
        guard ticked > 0 else { return nil }
        return SessionRecord(workoutID: w.id, kind: w.kind, name: w.name, colour: w.colour, started: started, ended: ended,
                             completed: ticked >= w.exercises.count,
                             detail: "\(ticked) of \(w.exercises.count) exercise\(w.exercises.count == 1 ? "" : "s")")
    }

    public var minutes: Int { max(1, Int((ended.timeIntervalSince(started) / 60).rounded())) }
}

/// One line in History: a gym visit or a workout record.
public struct HistoryItem: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case gym(UUID)
        case workout(UUID)
    }

    public var source: Source
    public var date: Date
    /// "At the gym" or the workout's name.
    public var name: String
    /// The colour key: indigo for the gym, else the workout's.
    public var colour: String
    /// What the filter chips group by: "gym" or the workout's id.
    public var group: String
    /// The hand-drawn icon key: the gym's, or the workout kind's.
    public var icon: String = "strength"
    public var title: String?
    public var notes: String?
    public var detail: String
    public var minutes: Int?
    public var kg: Double
    public var completed: Bool

    public var id: Source { source }
    /// The heading shown: the given title, else the name.
    public var heading: String { title ?? name }
}

/// This week or month in numbers.
public struct HistoryTotals: Equatable, Sendable {
    public var sessions: Int
    public var minutes: Int
    public var kg: Double
}

public enum History {
    public static let gymGroup = "gym"

    /// Every gym visit and every workout record, newest first.
    public static func items(records: [SessionRecord], gym: GymLog) -> [HistoryItem] {
        let visits = gym.visits.filter { $0.setCount > 0 }.map { v in
            let place = gym.gyms.first { $0.id == v.gymID }?.name
            return HistoryItem(source: .gym(v.id), date: v.started ?? v.date,
                               name: place.map { "At the gym · \($0)" } ?? "At the gym", colour: "indigo",
                               group: gymGroup, title: v.title, notes: v.notes,
                               // Push-ups only: no "0 kg" (since 1.6).
                               detail: "\(v.entries.count) machine\(v.entries.count == 1 ? "" : "s") · \(v.setCount) set\(v.setCount == 1 ? "" : "s")"
                                   + (v.totalKg > 0 ? " · \(GymSet.number(v.totalKg)) kg" : ""),
                               minutes: v.minutes, kg: v.totalKg, completed: true)
        }
        let done = records.map { r in
            HistoryItem(source: .workout(r.id), date: r.started, name: r.name, colour: r.colour,
                        group: r.workoutID?.uuidString ?? r.name, icon: r.kind.iconKey, title: r.title, notes: r.notes,
                        detail: r.completed ? r.detail : r.detail + " · ended early",
                        minutes: r.minutes, kg: 0, completed: r.completed)
        }
        return (visits + done).sorted { $0.date > $1.date }
    }

    public static func totals(_ items: [HistoryItem], in interval: DateInterval) -> HistoryTotals {
        let inside = items.filter { interval.contains($0.date) }
        return HistoryTotals(sessions: inside.count,
                             minutes: inside.reduce(0) { $0 + ($1.minutes ?? 0) },
                             kg: inside.reduce(0) { $0 + $1.kg })
    }

    /// This calendar week (Monday first in Sweden) or month, around `now`.
    public static func period(_ component: Calendar.Component, around now: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 0)
    }

    /// Weeks in a row with at least one session, counting back from this week
    /// (this week still counts as unbroken while it has nothing yet).
    public static func weekStreak(_ items: [HistoryItem], now: Date, calendar: Calendar = .current) -> Int {
        func has(_ week: DateInterval) -> Bool { items.contains { week.contains($0.date) } }
        func before(_ week: DateInterval) -> DateInterval? {
            calendar.date(byAdding: .day, value: -1, to: week.start).map { period(.weekOfYear, around: $0, calendar: calendar) }
        }
        var week: DateInterval? = period(.weekOfYear, around: now, calendar: calendar)
        if let w = week, !has(w) { week = before(w) }
        var streak = 0
        while let w = week, has(w) {
            streak += 1
            week = before(w)
        }
        return streak
    }

    /// Minutes and sessions per week, the last `weeks` weeks, oldest first — for the bar chart.
    public static func weekly(_ items: [HistoryItem], weeks: Int = 8, now: Date,
                              calendar: Calendar = .current) -> [(start: Date, minutes: Int, sessions: Int)] {
        let this = period(.weekOfYear, around: now, calendar: calendar)
        return (0..<weeks).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: this.start) else { return nil }
            let t = totals(items, in: period(.weekOfYear, around: start, calendar: calendar))
            return (start, t.minutes, t.sessions)
        }
    }
}

/// `history.json`: `{"version":1,"sessions":[…]}`.
public enum HistoryFile {
    struct Envelope: Codable {
        var version: Int
        var sessions: [SessionRecord]
    }

    public static func encode(_ records: [SessionRecord]) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(Envelope(version: 1, sessions: records))
    }

    public static func decode(_ data: Data) throws -> [SessionRecord] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Envelope.self, from: data).sessions
    }
}
