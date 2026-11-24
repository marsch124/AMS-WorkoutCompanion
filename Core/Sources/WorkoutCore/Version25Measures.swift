import Foundation

/// A number a step of a Tailored intervals workout can carry (since 2.5, his pick: chosen per workout).
public enum StepMeasure: String, Codable, CaseIterable, Sendable {
    /// Minutes per kilometre, kept in seconds.
    case pace
    /// Watts.
    case power
    /// Kilos; halves allowed.
    case weight
    /// A machine's level, a whole number.
    case level

    public var title: String {
        switch self {
        case .pace: return "Pace"
        case .power: return "Power"
        case .weight: return "Weight"
        case .level: return "Level"
        }
    }

    /// The short unit beside the number in its box.
    public var unit: String {
        switch self {
        case .pace: return "/km"
        case .power: return "W"
        case .weight: return "kg"
        case .level: return "lvl"
        }
    }

    /// What he typed, as a number; nil when it is empty or makes no sense.
    /// Pace: "5:30", "5.30", "5,30" and "530" are all 5 minutes 30 seconds; a plain "5" is 5:00.
    public func parse(_ typed: String) -> Double? {
        let t = typed.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        switch self {
        case .pace:
            let parts = t.split(whereSeparator: { ":.,".contains($0) }).map(String.init)
            let minutes: Int, seconds: Int
            switch parts.count {
            case 1:
                guard let n = Int(parts[0]), n >= 0 else { return nil }
                if parts[0].count >= 3 { minutes = n / 100; seconds = n % 100 } else { minutes = n; seconds = 0 }
            case 2:
                guard let m = Int(parts[0]), let s = Int(parts[1].count == 1 ? parts[1] + "0" : parts[1]), m >= 0 else { return nil }
                minutes = m; seconds = s
            default:
                return nil
            }
            guard (0..<60).contains(seconds), minutes < 100, minutes * 60 + seconds > 0 else { return nil }
            return Double(minutes * 60 + seconds)
        case .power, .level:
            guard let n = Int(t), n > 0, n < 10000 else { return nil }
            return Double(n)
        case .weight:
            guard let n = Double(t.replacingOccurrences(of: ",", with: ".")), n > 0, n < 10000 else { return nil }
            return (n * 10).rounded() / 10
        }
    }

    /// The number as it stands in its box, without the unit: "5:30", "150", "22.5", "8".
    public func text(_ value: Double) -> String {
        switch self {
        case .pace:
            let s = Int(value.rounded())
            return String(format: "%d:%02d", s / 60, s % 60)
        case .power, .level:
            return "\(Int(value.rounded()))"
        case .weight:
            return value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        }
    }

    /// The number with its unit, as shown on the run screen and the plan: "5:30 /km", "150 W", "20 kg", "Level 8".
    public func shown(_ value: Double) -> String {
        self == .level ? "Level \(text(value))" : "\(text(value)) \(unit)"
    }

    /// The number as the voice says it.
    public func spoken(_ value: Double) -> String {
        switch self {
        case .pace: return "\(text(value)) per kilometre"
        case .power: return "\(text(value)) watts"
        case .weight: return "\(text(value)) kilos"
        case .level: return "Level \(text(value))"
        }
    }
}

extension IntervalStep {
    /// The step's number for a measure; nil when he gave none.
    public func value(_ measure: StepMeasure) -> Double? { values[measure.rawValue] }

    public mutating func set(_ measure: StepMeasure, _ value: Double?) {
        values[measure.rawValue] = value
    }
}

extension Workout {
    /// What the workout's steps carry, in the fixed order Pace, Power, Weight, Level.
    public var shownMeasures: [StepMeasure] { StepMeasure.allCases.filter { measures.contains($0) } }

    public mutating func toggle(_ measure: StepMeasure) {
        if measures.contains(measure) { measures.removeAll { $0 == measure } } else { measures.append(measure) }
    }

    /// What a step shows after its length — "5:30 /km · 150 W" — from the measures the workout uses,
    /// and a "Speed or power" text typed in 2.4, which is kept. Nil when there is nothing.
    public func detail(at index: Int) -> String? {
        guard steps.indices.contains(index) else { return nil }
        let step = steps[index]
        let parts = shownMeasures.compactMap { m in step.value(m).map { m.shown($0) } } + [step.shownTarget].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{B7} ")
    }

    /// The same for the voice: "5:30 per kilometre. 150 watts".
    public func spokenDetail(at index: Int) -> String? {
        guard steps.indices.contains(index) else { return nil }
        let step = steps[index]
        let parts = shownMeasures.compactMap { m in step.value(m).map { m.spoken($0) } } + [step.shownTarget].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// The position of the step behind a running phase; nil for a get ready.
    public func stepIndex(of phase: Phase?) -> Int? {
        guard case .step(_, _, let number, _)? = phase, steps.indices.contains(number - 1) else { return nil }
        return number - 1
    }
}
