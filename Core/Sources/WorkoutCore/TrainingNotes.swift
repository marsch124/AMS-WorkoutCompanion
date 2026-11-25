import Foundation

/// 3.1: the notes shared with AMS Triathlon Training (and AMS Magic Morning) through one small
/// Keychain item. This file is only the model: bytes in, bytes out, no Keychain and no screen.
/// Rules (the contract of the three apps): read, change, write — never write blind; keep every field
/// this version does not know; keep only the notes of the last 14 days; a note made once is never made
/// twice; a higher `format` than known means read nothing and write nothing.
public enum TrainingNotes {
    /// The newest format this version understands.
    public static let knownFormat = 1
    /// Notes older than this many days are dropped when a note is written.
    public static let keepDays = 14

    /// A finished strength workout, as the training app will read it.
    public struct Note: Equatable, Sendable {
        /// The same finished workout always gives the same id, so it is never counted twice.
        public var id: String
        public var title: String
        public var minutes: Int
        /// 1 to 10, only when the app has such a number for the workout (it has none today).
        public var effort: Int?
        public var at: Date

        public init(id: String, title: String, minutes: Int, effort: Int? = nil, at: Date) {
            self.id = id
            self.title = title
            self.minutes = minutes
            self.effort = effort
            self.at = at
        }
    }

    /// Any piece of JSON, so fields this version does not know survive a read-change-write.
    enum JSON: Codable, Equatable {
        case null, bool(Bool), number(Double), string(String), array([JSON]), object([String: JSON])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .null }
            else if let v = try? c.decode(Bool.self) { self = .bool(v) }
            else if let v = try? c.decode(Double.self) { self = .number(v) }
            else if let v = try? c.decode(String.self) { self = .string(v) }
            else if let v = try? c.decode([JSON].self) { self = .array(v) }
            else { self = .object(try c.decode([String: JSON].self)) }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .null: try c.encodeNil()
            case .bool(let v): try c.encode(v)
            case .number(let v): try c.encode(v)
            case .string(let v): try c.encode(v)
            case .array(let v): try c.encode(v)
            case .object(let v): try c.encode(v)
            }
        }

        var string: String? { if case .string(let s) = self { return s } else { return nil } }
        var number: Double? { if case .number(let n) = self { return n } else { return nil } }
    }

    /// The notes after `note` is added, as bytes to store — or nil when nothing may be written
    /// (a newer format, bytes that are not notes, or the note is already there).
    /// `existing` is what the Keychain holds now (nil when it holds nothing).
    public static func adding(_ note: Note, to existing: Data?, now: Date = Date(), calendar: Calendar = .current) -> Data? {
        var root: [String: JSON] = [:]
        if let existing, !existing.isEmpty {
            guard let decoded = try? JSONDecoder().decode(JSON.self, from: existing),
                  case .object(let o) = decoded else { return nil }
            root = o
        }
        if let f = root["format"]?.number, f > Double(knownFormat) { return nil }
        root["format"] = .number(Double(knownFormat))

        var done: [JSON] = []
        if case .array(let list)? = root["done"] { done = list }
        // The same note twice: nothing to write.
        if done.contains(where: { if case .object(let o) = $0 { return o["id"]?.string == note.id } else { return false } }) {
            return nil
        }
        done.append(.object(object(for: note, calendar: calendar)))
        done = done.filter { isRecent($0, now: now, calendar: calendar) }
        root["done"] = .array(done)
        return try? JSONEncoder().encode(JSON.object(root))
    }

    /// The notes with this note taken out (Undo Finish, Discard session). nil when there is nothing to change.
    public static func removing(id: String, from existing: Data?) -> Data? {
        guard let existing, let decoded = try? JSONDecoder().decode(JSON.self, from: existing),
              case .object(var root) = decoded,
              (root["format"]?.number ?? 1) <= Double(knownFormat),
              case .array(let list)? = root["done"] else { return nil }
        let kept = list.filter { if case .object(let o) = $0 { return o["id"]?.string != id } else { return true } }
        guard kept.count != list.count else { return nil }
        root["done"] = .array(kept)
        return try? JSONEncoder().encode(JSON.object(root))
    }

    /// The ids of the `done` notes held in these bytes (for tests and for the "already written" check).
    public static func doneIDs(in data: Data?) -> [String] {
        guard let data, let decoded = try? JSONDecoder().decode(JSON.self, from: data),
              case .object(let root) = decoded, case .array(let list)? = root["done"] else { return [] }
        return list.compactMap { if case .object(let o) = $0 { return o["id"]?.string } else { return nil } }
    }

    /// The note for a finished gym session. nil when its length is not known.
    public static func note(for visit: GymVisit) -> Note? {
        guard let finished = visit.finished, let minutes = visit.minutes, minutes > 0 else { return nil }
        return Note(id: visit.id.uuidString, title: "At the gym", minutes: minutes, at: finished)
    }

    /// The note for a finished Sets & reps workout (not for one ended early, not for the other kinds).
    public static func note(for record: SessionRecord) -> Note? {
        guard record.kind == .reps, record.completed else { return nil }
        return Note(id: record.id.uuidString, title: record.name, minutes: record.minutes, at: record.ended)
    }

    // MARK: Inside

    private static func object(for note: Note, calendar: Calendar) -> [String: JSON] {
        var o: [String: JSON] = [
            "id": .string(note.id),
            "day": .string(dayString(note.at, calendar: calendar)),
            "kind": .string("strength"),
            "title": .string(note.title),
            "minutes": .number(Double(note.minutes)),
            "at": .string(atString(note.at)),
            "from": .string("workouts"),
        ]
        if let e = note.effort, (1...10).contains(e) { o["effort"] = .number(Double(e)) }
        return o
    }

    /// Kept: a note of the last 14 days, today included (by its `day`, else its `at`), or one with no
    /// readable date. The same 14 days as the training app's own pruning (today and the 13 before it).
    private static func isRecent(_ item: JSON, now: Date, calendar: Calendar) -> Bool {
        guard case .object(let o) = item else { return true }
        let date: Date?
        if let d = o["day"]?.string, let parsed = parseDay(d, calendar: calendar) { date = parsed }
        else if let a = o["at"]?.string { date = ISO8601DateFormatter().date(from: a) }
        else { date = nil }
        guard let date else { return true }
        let today = calendar.startOfDay(for: now)
        guard let oldest = calendar.date(byAdding: .day, value: -(keepDays - 1), to: today) else { return true }
        return calendar.startOfDay(for: date) >= oldest
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func parseDay(_ s: String, calendar: Calendar) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func atString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
