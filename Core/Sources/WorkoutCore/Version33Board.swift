import Foundation

// Version 3.3: the planning board (iPad and Mac) — the rules it needs.

extension GymLog {
    /// The set a machine will start with next time: its last entry's plan (`nextTime`), else what a new
    /// visit would offer. Nil when the machine does not exist.
    public func startingSet(_ machineID: UUID) -> GymSet? {
        guard let m = machine(machineID) else { return nil }
        let fresh = GymVisit(gymID: m.gymID, date: Date.distantFuture)
        return next(machineID, in: fresh).set
    }

    /// True when the machine has a plan of its own from its last visit ("Your plan from last time").
    public func hasPlannedStart(_ machineID: UUID) -> Bool {
        last(machineID)?.entry.nextTime != nil
    }

    /// Writes the numbers a machine starts with next time on its latest entry with sets, keeping that
    /// entry's note. A machine never used has no entry yet: nothing changes and it returns false.
    @discardableResult
    public mutating func setStartingSet(_ set: GymSet?, machine machineID: UUID) -> Bool {
        guard let found = last(machineID) else { return false }
        nextTime(visit: found.visit.id, machine: machineID, set: set, note: found.entry.note ?? "")
        return true
    }

    /// The day of this gym's other plan that saving a plan for `day` would replace (one plan per gym).
    /// Nil when there is none, or it is the same day.
    public func planDayWarning(for day: Date, gym: UUID?, calendar: Calendar = .current) -> Date? {
        guard let other = plans.first(where: { $0.gymID == gym }),
              !calendar.isDate(other.day, inSameDayAs: day) else { return nil }
        return other.day
    }
}
