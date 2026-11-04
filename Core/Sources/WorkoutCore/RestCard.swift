import Foundation

/// What a rest shows on the lock screen and in the Dynamic Island (since 1.15):
/// what you rest from, what comes next, and when the rest began and ends.
public struct RestCard: Codable, Hashable, Sendable {
    /// The gym log (indigo) or a Sets & reps / interval workout (blue).
    public enum Kind: String, Codable, Hashable, Sendable { case gym, workout }

    public var kind: Kind
    /// "Leg press", or the workout's name.
    public var title: String
    /// "Set 3 · 40 kg × 10", "Set 2 of 3, 12 reps".
    public var next: String
    public var start: Date
    public var end: Date

    public init(kind: Kind, title: String, next: String, start: Date, end: Date) {
        self.kind = kind
        self.title = title
        self.next = next
        self.start = start
        self.end = max(end, start)
    }

    /// The length of the rest, whole seconds.
    public var seconds: Int { Int(end.timeIntervalSince(start).rounded()) }

    /// Seconds still to go, never below zero.
    public func left(at now: Date) -> TimeInterval { max(0, end.timeIntervalSince(now)) }

    /// How much of the rest has passed, 0 to 1.
    public func progress(at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    public func isOver(at now: Date) -> Bool { now >= end }
}

extension GymLog {
    /// The rest after a set on a machine: its name and the numbers offered for the next set.
    public func restCard(machine machineID: UUID, in visit: GymVisit, start: Date, end: Date) -> RestCard {
        let done = visit.entries.last { $0.machineID == machineID }?.sets.count ?? 0
        let numbers = text(next(machineID, in: visit).set, machine: machineID)
        return RestCard(kind: .gym, title: machine(machineID)?.name ?? "Rest",
                        next: "Set \(done + 1) · \(numbers)", start: start, end: end)
    }
}

/// The rest ring's colour (since 1.16): orange while most of the rest is left, yellow past the
/// middle, green when the next set is close.
public enum RestColour {
    public static func key(fractionLeft: Double) -> String {
        fractionLeft > 0.5 ? "orange" : fractionLeft > 0.2 ? "yellow" : "green"
    }
}

extension GymLog {
    /// A working set that is more than the same set last time (since 1.16): more weight, or the
    /// same weight with more reps; on a reps-only exercise, more reps. `index` is the set's place
    /// in today's list on the machine (warm-ups count there, but are never compared).
    /// Time machines, warm-ups and a first time on a machine: never.
    public func beatsLastTime(_ set: GymSet, at index: Int, machine machineID: UUID, visit visitID: UUID) -> Bool {
        guard !set.isWarmup, !set.isTime, let last = last(machineID, excluding: visitID) else { return false }
        let today = visits.first { $0.id == visitID }?.entries.last { $0.machineID == machineID }?.sets ?? []
        let place = today.prefix(index).filter { !$0.isWarmup }.count
        let before = last.entry.working
        guard place < before.count else { return false }
        let then = before[place]
        if machine(machineID)?.logs == .reps { return set.reps > then.reps }
        return set.kg > then.kg || (set.kg == then.kg && set.reps > then.reps)
    }
}
