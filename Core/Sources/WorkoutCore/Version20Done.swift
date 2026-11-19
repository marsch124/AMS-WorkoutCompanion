import Foundation

/// 2.0, the Well done page: the week count, the trophy rule and the words for the warm-up and stretching.
extension GymLog {
    /// Finished visits in the week (Monday to Sunday) of `date`, plus the visit `including` itself,
    /// which counts even before its Finish is stored.
    public func sessionsThisWeek(containing date: Date, including: UUID? = nil, calendar: Calendar = .current) -> Int {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        guard let week = cal.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return visits.filter { v in
            week.contains(v.date) && (v.finished != nil || v.id == including)
        }.count
    }

    /// The warm-up's name: the machine for cardio, else the kind in words.
    public func warmupName(_ part: VisitPart) -> String {
        switch part.kind {
        case .cardio: return part.machineID.flatMap { machine($0)?.name } ?? "Cardio machine"
        case .moves: return "Warm-up moves"
        case .outside: return "Walk or run to the gym"
        case .stretch: return "Stretching"
        }
    }
}

extension GymVisit {
    /// "6 stretches" / "1 stretch" — what was held, else what was chosen; nil when unknown.
    public var stretchCountText: String? {
        guard let s = stretching else { return nil }
        let n = s.held ?? s.names?.count
        guard let n, n > 0 else { return nil }
        return n == 1 ? "1 stretch" : "\(n) stretches"
    }

    /// "Warm-up 8 min · Treadmill" for the share picture; nil without a warm-up.
    public func warmupLine(in gym: GymLog) -> String? {
        guard let w = warmup else { return nil }
        return "Warm-up \(w.minutes) min · \(gym.warmupName(w))"
    }

    /// "Stretching 9 min · 6 stretches"; nil without stretching.
    public func stretchLine() -> String? {
        guard let s = stretching else { return nil }
        return "Stretching \(s.minutes) min" + (stretchCountText.map { " · " + $0 } ?? "")
    }

    /// "3rd" style words for the week tile: "3rd this week".
    public static func ordinal(_ n: Int) -> String {
        let t = n % 100
        let suffix = (11...13).contains(t) ? "th" : ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
        return "\(n)\(suffix)"
    }
}
