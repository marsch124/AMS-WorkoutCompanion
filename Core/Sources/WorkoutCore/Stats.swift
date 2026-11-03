import Foundation

/// The numbers behind History's statistics (since 1.9): all pure, so they can be tested.
public struct StatsOverview: Equatable, Sendable {
    public var sessions: Int
    public var minutes: Int
    /// Machines and exercises used: one per machine per gym visit, added up.
    public var exercises: Int
    public var sets: Int
    public var kg: Double
}

/// Sets on one muscle group; `muscle` nil = not chosen yet.
public struct MuscleCount: Equatable, Sendable {
    public var muscle: MuscleGroup?
    public var sets: Int
}

/// Minutes on one time machine (treadmill, rower …).
public struct CardioMinutes: Equatable, Sendable {
    public var name: String
    public var minutes: Int
}

public struct Badge: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    /// How to get it.
    public var hint: String
    /// The hand-drawn icon key.
    public var icon: String
    public var earned: Bool
}

/// One machine's best ever, for the Records wall (since 1.11).
public struct RecordRow: Identifiable, Equatable, Sendable {
    public var machine: Machine
    /// The best set: heaviest weight (most reps at it), most reps on an exercise, longest time on a time machine.
    public var set: GymSet
    /// The day it was first done.
    public var date: Date
    public var visitID: UUID
    public var id: UUID { machine.id }
}

/// Sets per week for one muscle group, oldest week first (since 1.11).
public struct MuscleWeeks: Equatable, Sendable {
    /// nil = machines with no group chosen.
    public var muscle: MuscleGroup?
    public var weeks: [Int]
    public var total: Int { weeks.reduce(0, +) }
}

public enum Stats {
    /// Gym visits that started in the interval.
    static func visits(_ gym: GymLog, in interval: DateInterval) -> [GymVisit] {
        gym.visits.filter { $0.setCount > 0 && interval.contains($0.started ?? $0.date) }
    }

    public static func overview(_ items: [HistoryItem], gym: GymLog, in interval: DateInterval) -> StatsOverview {
        let t = History.totals(items, in: interval)
        let v = visits(gym, in: interval)
        return StatsOverview(sessions: t.sessions, minutes: t.minutes,
                             exercises: v.reduce(0) { $0 + $1.entries.filter { !$0.sets.isEmpty }.count },
                             sets: v.reduce(0) { $0 + $1.setCount }, kg: t.kg)
    }

    /// Sets per muscle group, biggest first (ties in your order). A time machine without a group
    /// counts as Cardio, any other machine without one as "not chosen" (nil, last). Groups with no
    /// sets are left out.
    public static func muscles(_ gym: GymLog, in interval: DateInterval) -> [MuscleCount] {
        var counts: [String?: Int] = [:]
        for e in visits(gym, in: interval).flatMap(\.entries) where !e.sets.isEmpty {
            counts[gym.muscle(for: gym.machine(e.machineID))?.id, default: 0] += e.sets.count
        }
        let chosen = gym.muscles.enumerated().compactMap { i, g in counts[g.id].map { (i, MuscleCount(muscle: g, sets: $0)) } }
            .sorted { $0.1.sets != $1.1.sets ? $0.1.sets > $1.1.sets : $0.0 < $1.0 }.map(\.1)
        return chosen + (counts[nil].map { [MuscleCount(muscle: nil, sets: $0)] } ?? [])
    }

    /// Minutes on time machines, per machine name, most first.
    public static func cardio(_ gym: GymLog, in interval: DateInterval) -> [CardioMinutes] {
        var seconds: [String: Int] = [:]
        for e in visits(gym, in: interval).flatMap(\.entries) {
            guard let m = gym.machine(e.machineID), m.logs == .time else { continue }
            seconds[m.name, default: 0] += e.sets.reduce(0) { $0 + ($1.seconds ?? 0) }
        }
        return seconds.map { CardioMinutes(name: $0.key, minutes: $0.value / 60) }
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.name < $1.name }
    }

    /// The longest run of weeks in a row with at least one session, ever.
    public static func bestStreak(_ items: [HistoryItem], calendar: Calendar = .current) -> Int {
        let starts = Set(items.map { History.period(.weekOfYear, around: $0.date, calendar: calendar).start }).sorted()
        var best = 0, run = 0
        var previous: Date?
        for s in starts {
            if let p = previous, let next = calendar.date(byAdding: .weekOfYear, value: 1, to: p), next == s { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = s
        }
        return best
    }

    /// New personal bests set in the interval: a machine's heaviest weight (reps-only: most reps in a set)
    /// beating everything done on it before that visit. The very first time on a machine is no record.
    public static func personalRecords(_ gym: GymLog, in interval: DateInterval) -> Int {
        var best: [UUID: Double] = [:]
        var count = 0
        for v in gym.visits.sorted(by: { ($0.started ?? $0.date) < ($1.started ?? $1.date) }) {
            var today: [UUID: Double] = [:]
            for e in v.entries {
                let score = e.sets.filter { $0.reps > 0 && !$0.isWarmup }.map { gym.score($0, machine: e.machineID) }.max() ?? 0
                if score > 0 { today[e.machineID] = max(today[e.machineID] ?? 0, score) }
            }
            for (id, score) in today {
                if let before = best[id], score > before, interval.contains(v.started ?? v.date) { count += 1 }
                best[id] = max(best[id] ?? 0, score)
            }
        }
        return count
    }

    /// Reps on reps-only exercises, and minutes on time machines, for each week (by the week's start).
    static func weekly(_ gym: GymLog, calendar: Calendar) -> (reps: [Date: Int], cardio: [Date: Int]) {
        var reps: [Date: Int] = [:], cardio: [Date: Int] = [:]
        for v in gym.visits {
            let week = History.period(.weekOfYear, around: v.started ?? v.date, calendar: calendar).start
            for e in v.entries {
                switch gym.machine(e.machineID)?.logs {
                case .reps: reps[week, default: 0] += e.sets.reduce(0) { $0 + $1.reps }
                case .time: cardio[week, default: 0] += e.sets.reduce(0) { $0 + ($1.seconds ?? 0) } / 60
                default: break
                }
            }
        }
        return (reps, cardio)
    }

    public static func badges(_ items: [HistoryItem], gym: GymLog, calendar: Calendar = .current) -> [Badge] {
        let w = weekly(gym, calendar: calendar)
        let streak = bestStreak(items, calendar: calendar)
        let heavy = gym.visits.contains { $0.totalKg >= 1000 }
        return [
            Badge(id: "first", title: "First session", hint: "Finish your first workout or gym visit", icon: "run", earned: items.count >= 1),
            Badge(id: "sessions10", title: "10 sessions", hint: "Do 10 sessions in all", icon: "strength", earned: items.count >= 10),
            Badge(id: "sessions50", title: "50 sessions", hint: "Do 50 sessions in all", icon: "trophy", earned: items.count >= 50),
            Badge(id: "streak4", title: "4 weeks in a row", hint: "Train in 4 weeks in a row", icon: "fire", earned: streak >= 4),
            Badge(id: "kg1000", title: "1000 kg in one visit", hint: "Lift 1000 kg in total in one gym visit", icon: "kettlebell", earned: heavy),
            Badge(id: "pushups100", title: "100 reps in a week", hint: "Do 100 reps of push-ups or other reps-only exercises in one week", icon: "mountain",
                  earned: w.reps.values.contains { $0 >= 100 }),
            Badge(id: "cardio60", title: "60 cardio minutes", hint: "Spend 60 minutes on time machines in one week", icon: "heart",
                  earned: w.cardio.values.contains { $0 >= 60 }),
        ]
    }

    // MARK: Since 1.11

    /// Every machine's best ever, newest record first. Warm-ups never count; machines never used are left out.
    public static func records(_ gym: GymLog) -> [RecordRow] {
        // The visit's day, not when its first set was typed: an earlier day logged later keeps its day.
        let visits = gym.visits.sorted { $0.date < $1.date }
        var rows: [UUID: RecordRow] = [:]
        func better(_ a: GymSet, than b: GymSet, logs: MachineLogs) -> Bool {
            switch logs {
            case .time: return (a.seconds ?? 0) > (b.seconds ?? 0)
            case .reps: return a.reps > b.reps
            case .weights: return a.kg != b.kg ? a.kg > b.kg : a.reps > b.reps
            }
        }
        for v in visits {
            for e in v.entries {
                guard let m = gym.machine(e.machineID) else { continue }
                for set in e.sets where !set.isWarmup && (set.reps > 0 || set.isTime) {
                    if let old = rows[m.id], !better(set, than: old.set, logs: m.logs) { continue }
                    rows[m.id] = RecordRow(machine: m, set: set, date: v.date, visitID: v.id)
                }
            }
        }
        return rows.values.sorted { $0.date != $1.date ? $0.date > $1.date : $0.machine.name < $1.machine.name }
    }

    /// Sets per muscle group in each of the last `weeks` weeks (this week last), every group in your
    /// order — groups with no sets too, so a neglected one shows as empty. Machines with no group come last,
    /// only when they have sets.
    public static func muscleWeeks(_ gym: GymLog, weeks: Int = 4, now: Date = Date(), calendar: Calendar = .current) -> [MuscleWeeks] {
        let thisWeek = History.period(.weekOfYear, around: now, calendar: calendar).start
        let starts = (0..<weeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        var counts: [String?: [Int]] = [:]
        for v in gym.visits {
            let week = History.period(.weekOfYear, around: v.date, calendar: calendar).start
            guard let w = starts.firstIndex(of: week) else { continue }
            for e in v.entries where !e.sets.isEmpty {
                let key = gym.muscle(for: gym.machine(e.machineID))?.id
                var row = counts[key] ?? Array(repeating: 0, count: weeks)
                row[w] += e.sets.count
                counts[key] = row
            }
        }
        var out = gym.muscles.map { MuscleWeeks(muscle: $0, weeks: counts[$0.id] ?? Array(repeating: 0, count: weeks)) }
        if let none = counts[nil] { out.append(MuscleWeeks(muscle: nil, weeks: none)) }
        return out
    }
}
