import Foundation

/// One step of a running workout.
public enum Phase: Equatable, Sendable {
    /// A short countdown before the first round.
    case getReady(seconds: Int)
    /// A set: no clock, it ends when he taps Done.
    case set(number: Int, of: Int, reps: Int)
    /// Rest between sets.
    case rest(seconds: Int, nextSet: Int, of: Int)
    /// A work round.
    case work(seconds: Int, round: Int, of: Int)
    /// Rest between rounds.
    case off(seconds: Int, nextRound: Int, of: Int)

    /// Length of a timed phase; nil for a set.
    public var seconds: Int? {
        switch self {
        case .getReady(let s), .rest(let s, _, _), .work(let s, _, _), .off(let s, _, _): return s
        case .set: return nil
        }
    }

    /// True for the phases where he is meant to be resting.
    public var isRest: Bool {
        switch self {
        case .rest, .off, .getReady: return true
        case .set, .work: return false
        }
    }
}

public enum Plan {
    public static let getReadySeconds = 5

    /// The phases of a workout, in order. An exercise list has none: it has no clock.
    public static func phases(for w: Workout) -> [Phase] {
        var out: [Phase] = []
        switch w.kind {
        case .reps:
            let sets = max(1, w.sets)
            for n in 1...sets {
                out.append(.set(number: n, of: sets, reps: w.reps))
                if n < sets, w.restSeconds > 0 {
                    out.append(.rest(seconds: w.restSeconds, nextSet: n + 1, of: sets))
                }
            }
        case .intervals:
            let rounds = max(1, w.rounds)
            out.append(.getReady(seconds: getReadySeconds))
            for r in 1...rounds {
                out.append(.work(seconds: max(1, w.workSeconds), round: r, of: rounds))
                if r < rounds, w.offSeconds > 0 {
                    out.append(.off(seconds: w.offSeconds, nextRound: r + 1, of: rounds))
                }
            }
        case .checklist:
            break
        }
        return out
    }
}

/// Walks through the phases against the wall clock. Times are stored as end
/// dates, not counted down, so a late or skipped tick never loses time.
public struct Session: Equatable, Sendable {
    public let phases: [Phase]
    public private(set) var index = 0
    public private(set) var endsAt: Date?
    public private(set) var pausedLeft: TimeInterval?
    public private(set) var started = false

    public init(phases: [Phase]) {
        self.phases = phases
    }

    public var isFinished: Bool { started && index >= phases.count }
    public var current: Phase? { index < phases.count ? phases[index] : nil }
    public var isPaused: Bool { pausedLeft != nil }

    public mutating func start(at now: Date) {
        index = 0
        started = true
        begin(at: now)
    }

    /// Done / Skip: straight on to the next phase.
    public mutating func next(at now: Date) {
        guard started, index < phases.count else { return }
        index += 1
        begin(at: now)
    }

    /// Seconds left in a timed phase; nil for a set or when finished.
    public func remaining(at now: Date) -> TimeInterval? {
        if let p = pausedLeft { return p }
        guard let e = endsAt else { return nil }
        return max(0, e.timeIntervalSince(now))
    }

    /// How much of the timed phase is still left, 1 → 0.
    public func fractionLeft(at now: Date) -> Double {
        guard let r = remaining(at: now), let total = current?.seconds, total > 0 else { return 0 }
        return min(1, max(0, r / Double(total)))
    }

    /// Moves on when a timed phase has run out — several, if the app was away.
    /// Returns true when the phase changed.
    @discardableResult
    public mutating func tick(at now: Date) -> Bool {
        guard started, pausedLeft == nil else { return false }
        var changed = false
        while let e = endsAt, now >= e, index < phases.count {
            index += 1
            begin(at: e)
            changed = true
        }
        return changed
    }

    public mutating func pause(at now: Date) {
        guard let e = endsAt, pausedLeft == nil else { return }
        pausedLeft = max(0, e.timeIntervalSince(now))
        endsAt = nil
    }

    public mutating func resume(at now: Date) {
        guard let p = pausedLeft else { return }
        endsAt = now.addingTimeInterval(p)
        pausedLeft = nil
    }

    public mutating func addTime(_ seconds: TimeInterval) {
        if let p = pausedLeft {
            pausedLeft = p + seconds
        } else if let e = endsAt {
            endsAt = e.addingTimeInterval(seconds)
        }
    }

    /// 0 → 1 over the whole workout, for the bar at the top.
    public var progress: Double {
        phases.isEmpty ? 1 : Double(min(index, phases.count)) / Double(phases.count)
    }

    private mutating func begin(at start: Date) {
        pausedLeft = nil
        if let s = current?.seconds {
            endsAt = start.addingTimeInterval(TimeInterval(s))
        } else {
            endsAt = nil
        }
    }
}
