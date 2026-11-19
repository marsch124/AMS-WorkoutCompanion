import Foundation

/// The warm-up before the machines or the stretching after them (since 2.0).
/// Kept on the visit (`GymVisit.warmup` / `.stretching`), never as sets, so warm-up minutes never
/// count as cardio minutes, records or machines done.
public struct VisitPart: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// On one of his time machines: treadmill, bike, rower …
        case cardio
        /// Warm-up moves with pictures (arm circles, leg swings …).
        case moves
        /// Walk or run to the gym.
        case outside
        /// The stretching after the machines.
        case stretch
    }

    public var kind: Kind
    public var start: Date
    /// Nil while it runs.
    public var end: Date?
    /// Cardio: the machine used.
    public var machineID: UUID?
    /// The minutes he set before starting.
    public var plannedMinutes: Int?
    /// Cardio: km/h, level, and the average heart rate (typed, or read from Apple Health).
    public var speed: Double?
    public var level: Double?
    public var heartRate: Int?
    /// Moves or stretches done, by library id (or own-stretch id), in the order done.
    public var names: [String]?
    /// Stretches held to the end and skipped.
    public var held: Int?
    public var skipped: Int?

    public init(kind: Kind, start: Date, end: Date? = nil, machineID: UUID? = nil, plannedMinutes: Int? = nil) {
        self.kind = kind
        self.start = start
        self.end = end
        self.machineID = machineID
        self.plannedMinutes = plannedMinutes
    }

    enum CodingKeys: String, CodingKey { case kind, start, end, machineID, plannedMinutes, speed, level, heartRate, names, held, skipped }

    /// Anything odd reads as a walk to the gym, never as a broken file.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .outside
        start = try c.decode(Date.self, forKey: .start)
        end = (try? c.decodeIfPresent(Date.self, forKey: .end)) ?? nil
        machineID = (try? c.decodeIfPresent(UUID.self, forKey: .machineID)) ?? nil
        plannedMinutes = (try? c.decodeIfPresent(Int.self, forKey: .plannedMinutes)) ?? nil
        speed = (try? c.decodeIfPresent(Double.self, forKey: .speed)) ?? nil
        level = (try? c.decodeIfPresent(Double.self, forKey: .level)) ?? nil
        heartRate = (try? c.decodeIfPresent(Int.self, forKey: .heartRate)) ?? nil
        names = (try? c.decodeIfPresent([String].self, forKey: .names)) ?? nil
        held = (try? c.decodeIfPresent(Int.self, forKey: .held)) ?? nil
        skipped = (try? c.decodeIfPresent(Int.self, forKey: .skipped)) ?? nil
    }

    /// Whole minutes from start to end, rounded; 0 while it still runs.
    public var minutes: Int {
        guard let end else { return 0 }
        return max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
    }
}

extension GymVisit {
    /// The visit's minutes split into warm-up, machines and stretching (since 2.0) — for the bar on
    /// the Well done screen. Old visits: (0, minutes, 0).
    public var split: (warmup: Int, machines: Int, stretch: Int) {
        let w = warmup?.minutes ?? 0
        let s = stretching?.minutes ?? 0
        let all = minutes ?? 0
        return (w, max(0, all - w - s), s)
    }
}
