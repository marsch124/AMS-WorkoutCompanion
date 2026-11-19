import Foundation

extension GymLog {
    /// Starts the warm-up (since 2.0): gets or makes today's visit at this gym the way the first set does,
    /// stores the warm-up on it (never as sets) and starts the session clock at this moment.
    /// Returns the visit's id.
    @discardableResult
    public mutating func startWarmup(kind: VisitPart.Kind, gymID: UUID?, machineID: UUID? = nil, plannedMinutes: Int? = nil,
                                     at now: Date = Date(), calendar: Calendar = .current) -> UUID {
        var v = openVisit(on: now, gym: gymID, calendar: calendar) ?? GymVisit(gymID: gymID, date: now)
        if v.started == nil || (v.started ?? now) > now { v.started = now }
        v.warmup = VisitPart(kind: kind, start: now, machineID: machineID, plannedMinutes: plannedMinutes)
        if arrived?.gymID == gymID { arrived = nil }
        put(v)
        return v.id
    }

    /// The warm-up is over: its end, and what was done (speed, level, heart rate, moves).
    public mutating func endWarmup(visitID: UUID, at now: Date = Date(), speed: Double? = nil, level: Double? = nil,
                                   heartRate: Int? = nil, names: [String]? = nil) {
        guard var v = visits.first(where: { $0.id == visitID }), var w = v.warmup else { return }
        w.end = max(now, w.start)
        w.speed = speed
        w.level = level
        w.heartRate = heartRate
        w.names = names
        v.warmup = w
        put(v)
    }

    /// Changes a finished warm-up afterwards (minutes, speed, heart rate) — from the chip's sheet.
    public mutating func editWarmup(visitID: UUID, minutes: Int?, speed: Double?, level: Double?, heartRate: Int?) {
        guard var v = visits.first(where: { $0.id == visitID }), var w = v.warmup else { return }
        if let minutes, minutes > 0 { w.end = w.start.addingTimeInterval(Double(minutes) * 60) }
        w.speed = speed
        w.level = level
        w.heartRate = heartRate
        v.warmup = w
        put(v)
    }

    /// The stretching after the machines (since 2.0); nil takes it away.
    public mutating func setStretching(visitID: UUID, part: VisitPart?) {
        guard var v = visits.first(where: { $0.id == visitID }) else { return }
        v.stretching = part
        put(v)
    }
}
