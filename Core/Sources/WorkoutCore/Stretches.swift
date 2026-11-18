import Foundation

/// One stretch with its guide (since 1.30, his ask: "add a guide for the after-gym stretch").
public struct StretchMove: Hashable, Sendable {
    public let name: String
    /// "30 s each side"
    public let amount: String
    /// One short line, shown in the checklist.
    public let note: String
    /// How to do it, step by step (3–5 short steps).
    public let steps: [String]
    /// Where you should feel it.
    public let feel: String
    /// What to watch out for.
    public let careful: String

    public init(_ name: String, _ amount: String, note: String, steps: [String], feel: String, careful: String) {
        self.name = name; self.amount = amount; self.note = note; self.steps = steps; self.feel = feel; self.careful = careful
    }
}

/// A ready-made stretch list to choose in Settings → Reminder and stretch (since 1.30: the app's
/// own After-gym stretch plus six more). The id is fixed, so the list made from it is found again.
public struct StretchRoutine: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    /// One line: what it is for and how long it takes.
    public let summary: String
    /// An AMS-Icons colour key.
    public let colour: String
    public let moves: [StretchMove]

    /// The exercise list made from it.
    public func workout() -> Workout {
        Workout(id: id, name: name, kind: .checklist, colour: colour,
                exercises: moves.map { Exercise(name: $0.name, amount: $0.amount, note: $0.note) })
    }

    /// The guide for a stretch by its name, from any ready-made list.
    public static func move(named name: String) -> StretchMove? {
        all.lazy.flatMap(\.moves).first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The first is the app's own After-gym stretch; then the six added in 1.30.
    public static let all: [StretchRoutine] = StretchCatalog.routines
}
