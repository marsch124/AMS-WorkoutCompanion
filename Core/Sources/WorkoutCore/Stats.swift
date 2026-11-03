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
                let score = e.sets.filter { $0.reps > 0 }.map { gym.score($0, machine: e.machineID) }.max() ?? 0
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
}
