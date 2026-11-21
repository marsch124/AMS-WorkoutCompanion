import Foundation

/// Warm-up moves that fit today's machines (since 2.1).
public struct WarmupSuggestion: Equatable, Sendable {
    /// Library move ids (`dyn-…`), in the library's order.
    public var moves: [String]
    /// "legs, back": the muscle groups they were picked for, in his words.
    public var words: String

    public static let none = WarmupSuggestion(moves: [], words: "")
}

public extension GymLog {
    /// The machines today is about: today's plan at this gym (left-out machines not counted);
    /// with no plan, the machines of the last visit here before today.
    func todaysMachines(gym: UUID?, on day: Date, calendar: Calendar = .current) -> [UUID] {
        if let p = plan(on: day, gym: gym, calendar: calendar) {
            let order = p.order.filter { !p.skipped.contains($0) && machine($0) != nil }
            if !order.isEmpty { return order }
        }
        return lastOrder(gym: gym, before: day, calendar: calendar)
    }

    /// The muscle groups (chest, back, shoulders, arms, legs, core) of those machines, in order.
    func todaysMuscles(gym: UUID?, on day: Date, calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        for id in todaysMachines(gym: gym, on: day, calendar: calendar) {
            guard let g = machine(id)?.muscle, let key = Self.muscleKey(g, groups: muscles), !out.contains(key) else { continue }
            out.append(key)
        }
        return out
    }

    /// The warm-up moves that suit today's muscle groups, and those groups in his words.
    /// No plan and no last visit, or machines without a muscle group: nothing is suggested.
    func suggestedWarmupMoves(gym: UUID?, on day: Date, calendar: Calendar = .current) -> WarmupSuggestion {
        let keys = todaysMuscles(gym: gym, on: day, calendar: calendar)
        guard !keys.isEmpty else { return .none }
        let set = Set(keys)
        let moves = StretchLibrary.moves.filter { !set.isDisjoint(with: $0.muscles) }.map(\.id)
        guard !moves.isEmpty else { return .none }
        let words = keys.map { key in (muscles.first { $0.id == key }?.name ?? key).lowercased() }
        return WarmupSuggestion(moves: moves, words: words.joined(separator: ", "))
    }
}

public extension WarmPrefs {
    /// What the warm-up page shows (since 2.1): his remembered order first, then today's suggestions he
    /// has not got yet, then the rest. Ticked = his remembered ticks plus the suggestions (they only add).
    /// With nothing remembered: the suggestions alone are ticked, or every move when there are none.
    static func movesShown(saved: [String], suggested: [String]) -> (order: [String], ticked: Set<String>) {
        let all = StretchLibrary.moves.map(\.id)
        let mine = saved.filter { all.contains($0) }
        let extra = suggested.filter { all.contains($0) && !mine.contains($0) }
        let order = mine + extra + all.filter { !mine.contains($0) && !extra.contains($0) }
        let base = mine.isEmpty && extra.isEmpty ? all : mine
        return (order, Set(base + extra))
    }
}
