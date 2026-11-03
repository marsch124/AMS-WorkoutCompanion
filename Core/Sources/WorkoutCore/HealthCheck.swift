import Foundation

/// What "Check my data" found (since 1.8). Read-only: it only looks.
public struct HealthReport: Equatable, Sendable {
    public var unreadable: [String] = []
    public var workouts = 0
    public var machines = 0
    public var gymVisits = 0
    public var otherSessions = 0
    public var photos = 0
    public var missingPhotos: [String] = []
    public var keptAside: [String] = []
    public var beforeRestoreFolders: [String] = []

    /// Plain-words problems, one line each. Empty means all good.
    public var problems: [String] {
        var out: [String] = unreadable.map { "\($0) cannot be read." }
        if !missingPhotos.isEmpty {
            out.append("\(missingPhotos.count) photo\(missingPhotos.count == 1 ? " is" : "s are") missing.")
        }
        if !keptAside.isEmpty {
            out.append("\(keptAside.count) damaged file\(keptAside.count == 1 ? " was" : "s were") kept aside.")
        }
        return out
    }

    public var isAllGood: Bool { problems.isEmpty }
}

public enum HealthCheck {
    /// `files` holds the raw workouts.json, gym.json and history.json (nil or absent = not there yet).
    public static func run(files: [String: Data?], photoNames: Set<String>, otherFileNames: [String]) -> HealthReport {
        var r = HealthReport()
        var used = Set<String>()
        func data(_ name: String) -> Data? { files[name] ?? nil }

        if let d = data("workouts.json") {
            if let w = try? WorkoutFile.decode(d) {
                r.workouts = w.count
                used.formUnion(WorkoutFile.photosInUse(w))
            } else { r.unreadable.append("Your workouts file") }
        }
        if let d = data("gym.json") {
            if let g = try? GymFile.decode(d) {
                r.machines = g.machines.count
                r.gymVisits = g.visits.count
                used.formUnion(g.photosInUse)
            } else { r.unreadable.append("Your gym file") }
        }
        if let d = data("history.json") {
            if let h = try? HistoryFile.decode(d) { r.otherSessions = h.count }
            else { r.unreadable.append("Your History file") }
        }
        r.photos = photoNames.count
        r.missingPhotos = used.subtracting(photoNames).sorted()
        r.keptAside = otherFileNames.filter { $0.contains("-unreadable-") }.sorted()
        r.beforeRestoreFolders = otherFileNames.filter { $0.hasPrefix("Before restore") }.sorted()
        return r
    }
}
