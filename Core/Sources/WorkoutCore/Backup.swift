import Foundation

/// One backup file (since 1.6): workouts.json, gym.json, history.json and every photo, exactly as
/// they are on the iPhone, in one JSON file — `{"app":"AMS WorkoutCompanion","version":1,"made":…,
/// "files":{"gym.json":<base64>,…},"photos":{"<name>.jpg":<base64>,…}}`.
/// Restore writes the files back unchanged, so nothing is lost between versions.
public struct Backup: Codable, Equatable, Sendable {
    public static let appName = "AMS WorkoutCompanion"
    /// The data files a backup holds, in the app's Documents folder.
    public static let fileNames = ["workouts.json", "gym.json", "history.json"]

    public var app: String
    public var version: Int
    public var made: Date
    public var files: [String: Data]
    public var photos: [String: Data]

    public init(made: Date, files: [String: Data], photos: [String: Data]) {
        app = Backup.appName
        version = 1
        self.made = made
        self.files = files.filter { Backup.fileNames.contains($0.key) }
        self.photos = photos
    }

    /// What a backup holds, shown before Restore asks.
    public struct Contents: Equatable, Sendable {
        public var made: Date
        public var workouts: Int
        public var machines: Int
        public var visits: Int
        public var records: Int
        public var photos: Int

        /// "3 workouts · 12 machines · 40 gym visits · 25 other sessions · 30 photos".
        public var text: String {
            func n(_ count: Int, _ word: String) -> String { "\(count) \(word)\(count == 1 ? "" : "s")" }
            return [n(workouts, "workout"), n(machines, "machine"), n(visits, "gym visit"),
                    n(records, "other session"), n(photos, "photo")].joined(separator: " · ")
        }
    }

    /// Reads every file in the backup, so a damaged backup is refused before anything is changed.
    public func contents() throws -> Contents {
        let workouts = try files["workouts.json"].map(WorkoutFile.decode) ?? []
        let gym = try files["gym.json"].map(GymFile.decode) ?? GymLog()
        let records = try files["history.json"].map(HistoryFile.decode) ?? []
        return Contents(made: made, workouts: workouts.count, machines: gym.machines.count,
                        visits: gym.visits.count, records: records.count, photos: photos.count)
    }

    public enum Problem: Error, Equatable {
        /// Not a WorkoutCompanion backup, or from a newer version of the app.
        case notABackup
    }

    public static func encode(_ backup: Backup) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(backup)
    }

    public static func decode(_ data: Data) throws -> Backup {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let b = try? dec.decode(Backup.self, from: data), b.app == appName, b.version == 1 else {
            throw Problem.notABackup
        }
        return b
    }

    /// "Workouts backup 2026-11-03 1530.json".
    public static func fileName(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "Workouts backup %04d-%02d-%02d %02d%02d.json",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    /// A weekly copy is due when the newest one is 7 days old or there is none.
    public static func weeklyDue(newest: Date?, now: Date) -> Bool {
        guard let newest else { return true }
        return now.timeIntervalSince(newest) >= 7 * 24 * 3600
    }

    /// The automatic backup to the chosen folder (since 1.7) runs once per calendar day.
    public static func dailyDue(last: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let last else { return true }
        return !calendar.isDate(last, inSameDayAs: now)
    }

    /// The Train tab reminds after 14 days without a backup — counted from the oldest data when
    /// there never was one — and keeps quiet for 3 days after "Later" (since 1.8).
    public static func reminderDue(lastBackup: Date?, oldestData: Date?, later: Date?, now: Date) -> Bool {
        let day: TimeInterval = 24 * 3600
        guard let since = lastBackup ?? oldestData, now.timeIntervalSince(since) >= 14 * day else { return false }
        if let later, now.timeIntervalSince(later) < 3 * day { return false }
        return true
    }

    /// The weekly copies to remove so only the newest `keep` stay.
    public static func toRemove(_ made: [(name: String, date: Date)], keep: Int = 4) -> [String] {
        made.sorted { $0.date > $1.date }.dropFirst(keep).map(\.name)
    }
}
