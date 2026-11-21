import Foundation

/// Which sound plays when a rest ends (since 1.23).
public enum RestSound: String, CaseIterable, Codable, Sendable {
    /// A soft two-note rising chime (since 2.0), the rest-over sound for anyone who never chose one.
    case soft, chime, bell, beep, none

    public var title: String {
        switch self {
        case .soft: return "Soft chime"
        case .chime: return "Chime"
        case .bell: return "Bell"
        case .beep: return "Beep"
        case .none: return "None"
        }
    }
}

/// How strongly the phone buzzes during a workout.
public enum Buzz: String, CaseIterable, Codable, Sendable {
    case strong, light, off

    public var title: String {
        switch self {
        case .strong: return "Strong"
        case .light: return "Light"
        case .off: return "Off"
        }
    }
}

/// His sound choices. Missing fields fall back to how the app always sounded.
public struct SoundChoice: Codable, Equatable, Sendable {
    public var restSound: RestSound
    public var buzz: Buzz
    public var spokenCountdown: Bool

    public init(restSound: RestSound = .soft, buzz: Buzz = .strong, spokenCountdown: Bool = true) {
        self.restSound = restSound
        self.buzz = buzz
        self.spokenCountdown = spokenCountdown
    }

    private enum CodingKeys: String, CodingKey { case restSound, buzz, spokenCountdown }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        restSound = (try? c.decodeIfPresent(RestSound.self, forKey: .restSound)) ?? .soft
        buzz = (try? c.decodeIfPresent(Buzz.self, forKey: .buzz)) ?? .strong
        spokenCountdown = (try? c.decodeIfPresent(Bool.self, forKey: .spokenCountdown)) ?? true
    }
}

/// The word said aloud in an interval workout, if any.
public enum SpokenCue {
    /// `secondsLeft` counts down in whole seconds (3, 2, 1 …); `phaseLength` is the phase's full length.
    public static func word(secondsLeft: Int, phaseLength: Int, isWork: Bool) -> String? {
        switch secondsLeft {
        case 3: return "Three"
        case 2: return "Two"
        case 1: return "One"
        default: break
        }
        guard isWork else { return nil }
        if phaseLength >= 30, secondsLeft == 10 { return "Ten seconds" }
        if phaseLength >= 20, secondsLeft == phaseLength / 2 { return "Halfway" }
        return nil
    }
}

/// A ready-made or saved interval pattern.
public struct IntervalPreset: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var rounds: Int
    public var workSeconds: Int
    public var offSeconds: Int

    public init(id: String = UUID().uuidString, name: String, rounds: Int, workSeconds: Int, offSeconds: Int) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.workSeconds = workSeconds
        self.offSeconds = offSeconds
    }

    /// For example "8 × 20 s / 10 s".
    public var summary: String {
        "\(rounds) × \(workSeconds) s / \(offSeconds) s"
    }

    public static let builtIn: [IntervalPreset] = [
        IntervalPreset(id: "tabata", name: "Tabata", rounds: 8, workSeconds: 20, offSeconds: 10),
        IntervalPreset(id: "30-30", name: "30 / 30", rounds: 10, workSeconds: 30, offSeconds: 30),
        IntervalPreset(id: "40-20", name: "40 / 20", rounds: 8, workSeconds: 40, offSeconds: 20),
        IntervalPreset(id: "45-15", name: "45 / 15", rounds: 10, workSeconds: 45, offSeconds: 15),
        IntervalPreset(id: "every-minute", name: "Every minute", rounds: 10, workSeconds: 60, offSeconds: 0),
    ]
}
