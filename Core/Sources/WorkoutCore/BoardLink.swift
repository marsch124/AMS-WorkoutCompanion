import Foundation

/// The file the app writes for the Garmin Board on the Mac (since 1.24): the last finished gym
/// sessions, newest first. Format 1 — the Board reads it defensively, so new fields may be added.
public struct BoardFile: Codable, Equatable, Sendable {
    public static let name = "Workout Companion sessions.json"
    public static let most = 60

    public struct Entry: Codable, Equatable, Sendable {
        public var name: String
        public var muscle: String?
        /// "55 kg × 12, 11, 10"
        public var sets: String
        public var setCount: Int
        public var topKg: Double
        public var pain: Bool
    }

    public struct Session: Codable, Equatable, Sendable {
        public var id: UUID
        /// "2026-11-18", the day as the phone saw it.
        public var date: String
        public var start: Date?
        public var end: Date?
        public var minutes: Int?
        public var gym: String
        public var title: String?
        public var feel: String?
        public var notes: String?
        public var machines: Int
        public var sets: Int
        public var liftedKg: Double
        public var cardioMinutes: Int
        public var bests: [String]
        public var entries: [Entry]
    }

    public var app = "AMS Workout Companion"
    public var format = 1
    public var written: Date
    public var sessions: [Session]

    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(self)
    }
}

extension GymLog {
    /// The finished sessions with at least one set, as the Board file's sessions — newest first, at most 60.
    public func boardSessions(calendar: Calendar = .current) -> [BoardFile.Session] {
        var day = Date.ISO8601FormatStyle().year().month().day()
        day.timeZone = calendar.timeZone
        return visitsNewestFirst.filter { $0.finished != nil && $0.setCount > 0 }.prefix(BoardFile.most).map { v in
            let end: Date? = v.lastSetAt.map { last in
                if let f = v.finished, f >= last, f <= last.addingTimeInterval(GymVisit.finishGrace) { return f }
                return last
            }
            return BoardFile.Session(
                id: v.id, date: v.date.formatted(day), start: v.started, end: end, minutes: v.minutes,
                gym: gyms.first { $0.id == v.gymID }?.name ?? GymLog.firstGymName,
                title: v.title, feel: v.feel?.rawValue, notes: v.notes,
                machines: v.performed.count, sets: v.setCount, liftedKg: v.totalKg, cardioMinutes: v.minutesOnMachines,
                bests: bestsThen(v).compactMap { machine($0)?.name },
                entries: v.performed.map { e in
                    BoardFile.Entry(name: machine(e.machineID)?.name ?? "Machine",
                                    muscle: muscle(for: machine(e.machineID))?.name,
                                    sets: text(e), setCount: e.sets.count, topKg: e.heaviest, pain: e.pain == true)
                })
        }
    }

    /// The machines that reached a new best in this session, judged against the sessions BEFORE it only
    /// (the app's own "new bests" also looks at later ones, which is wrong for a list of past sessions).
    func bestsThen(_ visit: GymVisit) -> [UUID] {
        let when = visit.started ?? visit.date
        let earlier = visits.filter { $0.id != visit.id && ($0.started ?? $0.date) < when }
        var out: [UUID] = []
        for e in visit.performed where !out.contains(e.machineID) {
            let before = earlier.flatMap(\.entries).filter { $0.machineID == e.machineID }
                .flatMap(\.sets).filter { $0.reps > 0 && !$0.isWarmup }.map { score($0, machine: e.machineID) }.max()
            if let before, top(e.machineID, in: visit) > before { out.append(e.machineID) }
        }
        return out
    }

    /// The whole file, as it stands now.
    public func boardFile(now: Date = Date(), calendar: Calendar = .current) -> BoardFile {
        BoardFile(written: now, sessions: boardSessions(calendar: calendar))
    }
}
