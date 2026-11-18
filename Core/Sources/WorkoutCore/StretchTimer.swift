import Foundation

/// The guided stretch timer (since 1.32, his ask: cues in the AirPods during the stretch).
/// A list becomes phases: get ready → hold (side 1) → switch sides → hold (side 2) → next stretch.
public struct StretchPhase: Hashable, Sendable {
    public enum Kind: String, Sendable { case ready, hold, switchSides }
    public let kind: Kind
    /// Which stretch of the list (0-based).
    public let index: Int
    public let name: String
    /// 1 or 2; 0 when the stretch has no sides.
    public let side: Int
    public let sides: Int
    public let seconds: Int
    /// Said when the phase begins.
    public let spoken: String
}

public enum StretchTimer {
    /// Seconds to get into position before each stretch, and to swap sides.
    public static let readySeconds = 8
    public static let switchSeconds = 5
    /// When an amount gives no time.
    public static let usualHold = 30

    /// "30 s each side" → (30, 2); "60 s" → (60, 1); "1 min" → (60, 1); "2 × 10" → (30, 1).
    public static func hold(of amount: String) -> (seconds: Int, sides: Int) {
        let a = amount.lowercased()
        let sides = a.contains("each side") || a.contains("per side") || a.contains("each leg") || a.contains("each arm") ? 2 : 1
        let scanner = Scanner(string: a)
        var seconds: Int?
        while !scanner.isAtEnd {
            if let n = scanner.scanInt() {
                let rest = a[a.index(a.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: a))...]
                    .trimmingCharacters(in: .whitespaces)
                if rest.hasPrefix("s") { seconds = n; break }
                if rest.hasPrefix("min") { seconds = n * 60; break }
            } else {
                _ = scanner.scanCharacter()
            }
        }
        return (min(600, max(5, seconds ?? usualHold)), sides)
    }

    private static func said(_ seconds: Int) -> String {
        seconds % 60 == 0 && seconds >= 60
            ? (seconds == 60 ? "one minute" : "\(seconds / 60) minutes")
            : "\(seconds) seconds"
    }

    /// Every phase of the list, in order. Stretches with no name are left out.
    public static func phases(for exercises: [Exercise]) -> [StretchPhase] {
        let list = exercises.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        var out: [StretchPhase] = []
        for (i, e) in list.enumerated() {
            let (secs, sides) = hold(of: e.amount)
            let first = i == 0 ? "First" : i == list.count - 1 ? "Last one" : "Next"
            let each = sides == 2 ? "\(said(secs)) each side" : said(secs)
            out.append(StretchPhase(kind: .ready, index: i, name: e.name, side: sides == 2 ? 1 : 0, sides: sides,
                                    seconds: readySeconds, spoken: "\(first): \(e.name). \(each). Get into position."))
            out.append(StretchPhase(kind: .hold, index: i, name: e.name, side: sides == 2 ? 1 : 0, sides: sides,
                                    seconds: secs, spoken: sides == 2 ? "Hold. First side." : "Hold."))
            if sides == 2 {
                out.append(StretchPhase(kind: .switchSides, index: i, name: e.name, side: 2, sides: 2,
                                        seconds: switchSeconds, spoken: "Switch sides."))
                out.append(StretchPhase(kind: .hold, index: i, name: e.name, side: 2, sides: 2,
                                        seconds: secs, spoken: "Hold. Second side."))
            }
        }
        return out
    }

    /// The whole list's time in seconds.
    public static func total(_ phases: [StretchPhase]) -> Int { phases.reduce(0) { $0 + $1.seconds } }

    /// What the voice says partway through a phase: "Halfway", "Ten seconds", "Three", "Two", "One".
    public static func word(_ phase: StretchPhase, secondsLeft: Int) -> String? {
        if phase.kind == .switchSides { return nil }
        if phase.kind == .ready { return secondsLeft <= 3 && secondsLeft >= 1 ? ["One", "Two", "Three"][secondsLeft - 1] : nil }
        return SpokenCue.word(secondsLeft: secondsLeft, phaseLength: phase.seconds, isWork: true)
    }
}
