import Foundation

/// The spoken marks of a rest (since 2.0): "Thirty seconds", "Twenty seconds", "Ten seconds"
/// when they fall well inside the rest, then "Three, Two, One".
public enum RestCuePlan {
    /// The seconds-left marks, biggest first. 90 → 30, 20, 10, 3, 2, 1; 3 → none.
    public static func marks(restSeconds: Int) -> [Int] {
        var out = [30, 20, 10].filter { $0 <= restSeconds - 2 }
        if restSeconds >= 4 { out += [3, 2, 1] }
        return out
    }

    public static func words(for mark: Int) -> String? {
        switch mark {
        case 30: return "Thirty seconds"
        case 20: return "Twenty seconds"
        case 10: return "Ten seconds"
        case 3: return "Three"
        case 2: return "Two"
        case 1: return "One"
        default: return nil
        }
    }

    /// The mark to say now: the largest not-yet-said mark that has been reached (`secondsLeft`
    /// at or below it, within one second so a late tick still speaks it). nil = nothing to say.
    public static func due(secondsLeft: Double, marks: [Int], said: Set<Int>) -> Int? {
        marks.first { !said.contains($0) && secondsLeft <= Double($0) && secondsLeft > Double($0) - 1.0 }
    }
}
