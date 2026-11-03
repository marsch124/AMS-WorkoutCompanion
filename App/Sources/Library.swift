import SwiftUI
import UIKit
import WorkoutCore

/// The workouts on this iPhone: one JSON file and a folder of photos in Documents.
@MainActor
@Observable
final class Library {
    private(set) var workouts: [Workout] = []
    /// The gym log: machines and visits, in its own file.
    private(set) var gym = GymLog()
    /// Every Sets & reps, Interval and Exercise-list workout done (gym visits live in the gym log).
    private(set) var history: [SessionRecord] = []
    let folder: URL

    private var file: URL { folder.appendingPathComponent("workouts.json") }
    private var gymFile: URL { folder.appendingPathComponent("gym.json") }
    private var historyFile: URL { folder.appendingPathComponent("history.json") }
    var photoFolder: URL { folder.appendingPathComponent("Photos", isDirectory: true) }

    init(folder: URL) {
        self.folder = folder
        let fm = FileManager.default
        try? fm.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: file) {
            if let list = try? WorkoutFile.decode(data) {
                workouts = list
            } else {
                // Never overwrite a file we cannot read: keep it aside first.
                let aside = folder.appendingPathComponent("workouts-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: file, to: aside)
            }
        } else {
            workouts = Starters.all
            persist()
        }
        if let data = try? Data(contentsOf: gymFile) {
            if let log = try? GymFile.decode(data) {
                gym = log
            } else {
                gymUnreadable = true
                let aside = folder.appendingPathComponent("gym-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: gymFile, to: aside)
            }
        }
        if let data = try? Data(contentsOf: historyFile) {
            if let list = try? HistoryFile.decode(data) {
                history = list
            } else {
                historyUnreadable = true
                let aside = folder.appendingPathComponent("history-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: historyFile, to: aside)
            }
        }
    }

    /// True when history.json could not be read: it is kept aside and never overwritten.
    private var historyUnreadable = false

    /// True when gym.json could not be read: it is kept aside and never overwritten.
    private var gymUnreadable = false

    /// Documents on the iPhone; a fresh, empty folder for UI tests.
    static func launch() -> Library {
        let fm = FileManager.default
        if ProcessInfo.processInfo.arguments.contains("-uitest") {
            let dir = fm.temporaryDirectory.appendingPathComponent("uitest", isDirectory: true)
            try? fm.removeItem(at: dir)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if ProcessInfo.processInfo.arguments.contains("-gymdemo"),
               let data = try? GymFile.encode(GymLog.demo()) {
                try? data.write(to: dir.appendingPathComponent("gym.json"))
            }
            return Library(folder: dir)
        }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return Library(folder: docs)
    }

    func save(_ workout: Workout) {
        var w = workout
        w.name = w.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = workouts.firstIndex(where: { $0.id == w.id }) {
            workouts[i] = w
        } else {
            workouts.append(w)
        }
        persist()
    }

    func duplicate(_ workout: Workout) {
        var copy = workout
        copy.id = UUID()
        copy.name = workout.name + " (copy)"
        copy.exercises = workout.exercises.map { e in
            var e = e
            e.id = UUID()
            if let p = e.photo { e.photo = copyPhoto(p) }
            return e
        }
        let at = (workouts.firstIndex { $0.id == workout.id } ?? workouts.count - 1) + 1
        workouts.insert(copy, at: at)
        persist()
    }

    func delete(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        persist()
    }

    func move(from: IndexSet, to: Int) {
        workouts.move(fromOffsets: from, toOffset: to)
        persist()
    }

    // MARK: Gym

    /// Every change to the gym log goes through here and is written at once.
    /// The change works on a copy, so a closure that reads `gym` (a screen's visit or gym) while
    /// changing it cannot crash on overlapping access (the 1.4 plan-save crash).
    func changeGym(_ change: (inout GymLog) -> Void) {
        var log = gym
        change(&log)
        gym = log
        persistGym()
    }

    // MARK: History

    func record(_ r: SessionRecord) {
        history.append(r)
        persistHistory()
    }

    func describe(record id: UUID, title: String, notes: String) {
        guard let i = history.firstIndex(where: { $0.id == id }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        history[i].title = t.isEmpty ? nil : t
        history[i].notes = n.isEmpty ? nil : n
        persistHistory()
    }

    func deleteRecord(_ id: UUID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    /// Gym visits and workouts together, newest first.
    var historyItems: [HistoryItem] { History.items(records: history, gym: gym) }

    // MARK: Photos

    func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: photoFolder.appendingPathComponent(name).path)
    }

    /// Stores a picked photo, scaled down to 1600 px, and returns its file name.
    func storePhoto(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(1, longest))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = small.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: photoFolder.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    private func copyPhoto(_ name: String) -> String? {
        let new = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.copyItem(at: photoFolder.appendingPathComponent(name),
                                             to: photoFolder.appendingPathComponent(new))
            return new
        } catch {
            return nil
        }
    }

    // MARK: Saving

    private func persist() {
        guard let data = try? WorkoutFile.encode(workouts) else { return }
        try? data.write(to: file, options: .atomic)
        removeUnusedPhotos()
    }

    private func persistGym() {
        guard !gymUnreadable, let data = try? GymFile.encode(gym) else { return }
        try? data.write(to: gymFile, options: .atomic)
        removeUnusedPhotos()
    }

    private func persistHistory() {
        guard !historyUnreadable, let data = try? HistoryFile.encode(history) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }

    /// Photos no workout or machine uses any more (replaced, removed, deleted) go.
    private func removeUnusedPhotos() {
        // With an unreadable gym file we cannot know which photos its machines use: keep them all.
        guard !gymUnreadable else { return }
        let inUse = WorkoutFile.photosInUse(workouts).union(gym.photosInUse)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? []
        for name in names where !inUse.contains(name) {
            try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name))
        }
    }
}
