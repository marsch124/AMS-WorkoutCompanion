import Foundation

extension GymVisit {
    /// The machines of this session for a template (since 1.30, his ask: Save as template moved
    /// into finishing a session): every machine with at least one set, in the order used, each
    /// once, and only machines that still exist in the log.
    public func templateOrder(in log: GymLog) -> [UUID] {
        var order: [UUID] = []
        for e in entries where !e.sets.isEmpty && !order.contains(e.machineID) && log.machine(e.machineID) != nil {
            order.append(e.machineID)
        }
        return order
    }
}

extension GymLog {
    /// Discard session (since 1.30, his ask): the open session and all its sets are thrown away —
    /// nothing is kept in Earlier visits or History; the clock stops and the day's Busy marks and plan go,
    /// as after Finish.
    public mutating func discard(visit visitID: UUID, calendar: Calendar = .current) {
        guard let v = visits.first(where: { $0.id == visitID }) else { return }
        delete(visit: visitID)
        if arrived?.gymID == v.gymID { arrived = nil }
        busyMarks.removeAll { calendar.isDate($0.day, inSameDayAs: v.date) }
        plans.removeAll { $0.gymID == v.gymID && calendar.isDate($0.day, inSameDayAs: v.date) }
    }
}
