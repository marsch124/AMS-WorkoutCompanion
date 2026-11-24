import Foundation

/// One step of a Tailored intervals workout (since 2.3, his ask): its own name and its own length —
/// "Jog" 1:00, "Walk" 1:00, "Jog" 2:00 …
public struct IntervalStep: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// His word for the step; empty = "Step 3".
    public var name: String
    public var seconds: Int
    /// The speed or power to hold in this step, in his own words — "8 km/h", "150 W" (since 2.4). Empty = none.
    public var target: String
    /// An easy step — a walk between jogs — runs on a grey ring, like a rest (since 2.4). False = an effort step.
    public var easy: Bool

    public init(id: UUID = UUID(), name: String = "", seconds: Int = 60, target: String = "", easy: Bool = false) {
        self.id = id
        self.name = name
        self.seconds = seconds
        self.target = target
        self.easy = easy
    }

    /// The speed or power, trimmed; nil when he gave none.
    public var shownTarget: String? {
        let t = target.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds) ?? 60
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        easy = try c.decodeIfPresent(Bool.self, forKey: .easy) ?? false
    }

    /// The shortest and the longest a step can be, and the most steps one workout holds
    /// (iOS keeps at most 64 notifications waiting, and each coming step has one).
    public static let shortest = 5
    public static let longest = 3600
    public static let most = 60

    /// The ready lengths offered when he taps a step's time.
    public static let lengths: [Int] = [
        10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480, 600, 720, 900, 1200, 1800, 2700, 3600,
    ]

    /// − and +: by 5 seconds under one minute, by 15 seconds up to five minutes, by one minute above.
    public static func stepped(_ seconds: Int, up: Bool) -> Int {
        let next: Int
        if up {
            next = seconds + (seconds < 60 ? 5 : seconds < 300 ? 15 : 60)
        } else {
            next = seconds - (seconds <= 60 ? 5 : seconds <= 300 ? 15 : 60)
        }
        return min(longest, max(shortest, next))
    }

    /// What a new Tailored intervals workout starts with: his own example of 23 November 2026 —
    /// jog and walk 1, 2, 3, 2, 1 minutes, 18 minutes in all.
    public static var example: [IntervalStep] {
        [1, 2, 3, 2, 1].flatMap { minutes in
            [IntervalStep(name: "Jog", seconds: minutes * 60), IntervalStep(name: "Walk", seconds: minutes * 60, easy: true)]
        }
    }
}

extension Workout {
    /// Total time of a Tailored intervals workout, in seconds (no get-ready).
    public var tailoredTotal: Int { steps.reduce(0) { $0 + max(0, $1.seconds) } }

    /// The step's name as shown and spoken: his word, or "Step 3" when he gave none.
    public func stepName(at index: Int) -> String {
        guard steps.indices.contains(index) else { return "Step \(index + 1)" }
        let name = steps[index].name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Step \(index + 1)" : name
    }

    /// The step "Add step" appends: the name of the step two lines up — and, since 2.4, its speed or
    /// power and Effort / Easy — so Jog, Walk, Jog, Walk carries on by itself, and the length of the last step.
    public func nextStep() -> IntervalStep {
        let like = steps.count >= 2 ? steps[steps.count - 2] : nil
        return IntervalStep(name: like?.name ?? "", seconds: steps.last?.seconds ?? 60,
                            target: like?.target ?? "", easy: like?.easy ?? false)
    }

    /// The step behind a running phase; nil for a get ready.
    public func step(of phase: Phase?) -> IntervalStep? {
        guard case .step(_, _, let number, _)? = phase, steps.indices.contains(number - 1) else { return nil }
        return steps[number - 1]
    }

    /// A new workout of a kind. A Tailored one starts with the example, ready to change.
    public static func starting(_ kind: WorkoutKind) -> Workout {
        kind == .tailored ? Workout(kind: kind, steps: IntervalStep.example) : Workout(kind: kind)
    }
}

/// A length in words for the voice: "45 seconds", "2 minutes", "1 minute 30 seconds".
public enum SpokenLength {
    public static func words(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60, rest = s % 60
        var parts: [String] = []
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if rest > 0 || m == 0 { parts.append("\(rest) second\(rest == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }
}

/// What the voice says when a step starts (his pick: his word plus the length).
public enum TailoredCue {
    public static func start(name: String, seconds: Int, isLast: Bool, target: String? = nil) -> String {
        "\(isLast ? "Last step. " : "")\(name). \(SpokenLength.words(seconds)).\(target.map { " \($0)." } ?? "")"
    }
}

/// One notification of a Tailored intervals workout: it marks a change of step while the phone is
/// locked or the app is in the background, where the voice cannot speak.
public struct StepNotice: Equatable, Sendable {
    /// Seconds from now.
    public var after: TimeInterval
    public var title: String
    public var body: String

    public init(after: TimeInterval, title: String, body: String) {
        self.after = after
        self.title = title
        self.body = body
    }
}

extension Plan {
    /// The notifications still to come while phase `index` has `left` seconds to go: one for every
    /// later step, at the moment it starts, and one when the last phase ends.
    /// With `steps`, a step's speed or power follows its length: "Jog · 2:00 · 8 km/h" (since 2.4).
    public static func notices(phases: [Phase], index: Int, left: TimeInterval, name: String,
                               steps: [IntervalStep] = []) -> [StepNotice] {
        guard phases.indices.contains(index) else { return [] }
        var out: [StepNotice] = []
        var after = max(0, left)
        for phase in phases.dropFirst(index + 1) {
            if case .step(let seconds, let step, let number, let of) = phase {
                let target = steps.indices.contains(number - 1) ? steps[number - 1].shownTarget : nil
                out.append(StepNotice(after: after, title: "\(step) · \(Clock.text(seconds))\(target.map { " · \($0)" } ?? "")",
                                      body: "Step \(number) of \(of) · \(name)"))
            }
            after += TimeInterval(phase.seconds ?? 0)
        }
        out.append(StepNotice(after: after, title: "Workout complete", body: name))
        return Array(out.suffix(IntervalStep.most + 1).prefix(IntervalStep.most))
    }
}
