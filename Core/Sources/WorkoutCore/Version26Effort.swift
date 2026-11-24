import Foundation

/// How hard a step of a Tailored intervals workout is (since 2.6, his pick "Four ready efforts").
/// 2.4 had a button Effort / Easy, 2.5 none; now four ready words to tap, or none.
public enum StepEffort: String, Codable, CaseIterable, Sendable {
    case easy, steady, hard, allOut

    public var title: String {
        switch self {
        case .easy: return "Easy"
        case .steady: return "Steady"
        case .hard: return "Hard"
        case .allOut: return "All-out"
        }
    }
}

extension IntervalStep {
    /// An Easy step runs on a grey ring with a grey name, like a rest: "take it easy".
    public var isCalm: Bool { effort == .easy }
}
