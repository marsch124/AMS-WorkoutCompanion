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
