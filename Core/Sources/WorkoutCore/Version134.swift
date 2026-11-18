import Foundation

public extension SessionRecord {
    /// A guided stretch (since 1.34): how many of the chosen stretches were held.
    /// Saved also when stopped early; nothing when none was held.
    static func ofStretch(_ w: Workout, started: Date, ended: Date, held: Int, chosen: Int) -> SessionRecord? {
        guard held > 0 else { return nil }
        let all = w.exercises.count
        let of = chosen < all ? "\(held) of \(chosen) chosen stretches" : "\(held) of \(chosen) stretch\(chosen == 1 ? "" : "es")"
        return SessionRecord(workoutID: w.id, kind: w.kind, name: w.name, colour: w.colour, started: started, ended: ended,
                             completed: held >= chosen, detail: of)
    }
}

public extension StretchTimer {
    /// The stretches of a list that can be timed: those with a name (since 1.34, to choose from).
    static func choosable(_ exercises: [Exercise]) -> [Exercise] {
        exercises.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
