import Foundation

/// One line of a workout's plan, as the plan page shows it (since 1.28): "Sets" — "5".
public struct PlanLine: Hashable, Sendable {
    public let label: String
    public let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

extension Workout {
    /// The workout's plan in words, for the read-only plan page (since 1.28, his ask: a tap on a
    /// workout's panel only shows the plan). An exercise list has no lines here: the page lists
    /// its exercises one by one instead.
    public var plan: [PlanLine] {
        switch kind {
        case .reps:
            return [
                PlanLine("Sets", "\(sets)"),
                PlanLine("Reps each set", "\(reps)"),
                PlanLine("Rest between sets", restSeconds > 0 ? Clock.text(restSeconds) : "None"),
            ]
        case .intervals:
            return [
                PlanLine("Rounds", "\(rounds)"),
                PlanLine("Work", Clock.text(workSeconds)),
                PlanLine("Rest", offSeconds > 0 ? Clock.text(offSeconds) : "None"),
                PlanLine("Total time", Clock.text(intervalTotal)),
            ]
        case .tailored:
            return steps.indices.map {
                PlanLine("\($0 + 1) · \(stepName(at: $0))",
                         Clock.text(steps[$0].seconds) + (steps[$0].shownTarget.map { " · \($0)" } ?? ""))
            }
                + [PlanLine("Total time", Clock.text(tailoredTotal))]
        case .checklist:
            return []
        }
    }
}
