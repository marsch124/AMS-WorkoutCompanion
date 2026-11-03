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
        load()
    }

    /// Reads the three files; at launch and again after a restore.
    private func load() {
        let fm = FileManager.default
        try? fm.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        workouts = []
        gym = GymLog()
        history = []
        gymUnreadable = false
        historyUnreadable = false
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
        let library = Library(folder: docs)
        library.weeklyBackup()
        library.autoBackupIfDue()
        return library
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
        keepForUndo("\(workout.name) deleted")
        workouts.removeAll { $0.id == workout.id }
        persist()
    }

    // MARK: Undo (since 1.8)

    /// Everything as it was just before a delete; "Undo" puts it back for 10 seconds.
    struct UndoPoint: Identifiable {
        let id = UUID()
        let label: String
        let workouts: [Workout]
        let gym: GymLog
        let history: [SessionRecord]
    }
    private(set) var undoPoint: UndoPoint?

    /// Called just before a delete. Photos are not cleaned up while Undo can still bring them back.
    func keepForUndo(_ label: String) {
        undoPoint = UndoPoint(label: label, workouts: workouts, gym: gym, history: history)
    }

    func undo() {
        guard let p = undoPoint else { return }
        undoPoint = nil
        workouts = p.workouts
        gym = p.gym
        history = p.history
        persist()
        persistGym()
        persistHistory()
    }

    /// The Undo bar went away: from now on the delete stands and unused photos may go.
    func forgetUndo(_ id: UUID) {
        guard undoPoint?.id == id else { return }
        undoPoint = nil
        removeUnusedPhotos()
    }

    func move(from: IndexSet, to: Int) {
        workouts.move(fromOffsets: from, toOffset: to)
        persist()
    }

    // MARK: Gym

    /// Every change to the gym log goes through here and is written at once.
    /// The change works on a copy, so a closure that reads `gym` (a screen's visit or gym) while
    /// changing it cannot crash on overlapping access (the 1.4 plan-save crash).
    func changeGym(undo label: String? = nil, _ change: (inout GymLog) -> Void) {
        if let label { keepForUndo(label) }
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
        if let r = history.first(where: { $0.id == id }) { keepForUndo("\(r.name) deleted from History") }
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

    // MARK: Backups (since 1.6)

    /// Weekly copies stay in Documents/Backups on this iPhone (the newest 4).
    var backupFolder: URL { folder.appendingPathComponent("Backups", isDirectory: true) }

    /// Everything — the three files and every photo — as one backup.
    func makeBackup(at now: Date = Date()) -> Backup {
        let fm = FileManager.default
        var files: [String: Data] = [:]
        for name in Backup.fileNames {
            if let data = try? Data(contentsOf: folder.appendingPathComponent(name)) { files[name] = data }
        }
        var photos: [String: Data] = [:]
        for name in (try? fm.contentsOfDirectory(atPath: photoFolder.path)) ?? [] {
            if let data = try? Data(contentsOf: photoFolder.appendingPathComponent(name)) { photos[name] = data }
        }
        return Backup(made: now, files: files, photos: photos)
    }

    /// A backup file in the temporary folder, ready for the share sheet; nil when it could not be written.
    func backupFile() -> URL? {
        let b = makeBackup()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(Backup.fileName(b.made))
        guard let data = try? Backup.encode(b), (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        noteBackup(b.made)
        return url
    }

    /// Once a week, at launch: a copy in Backups; only the newest 4 are kept.
    func weeklyBackup(now: Date = Date(), force: Bool = false) {
        let fm = FileManager.default
        try? fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let copies = weeklyCopies()
        guard force || Backup.weeklyDue(newest: copies.first?.made, now: now),
              !workouts.isEmpty || !gym.machines.isEmpty || !history.isEmpty,
              let data = try? Backup.encode(makeBackup(at: now)) else { return }
        try? data.write(to: backupFolder.appendingPathComponent(Backup.fileName(now)), options: .atomic)
        let all = weeklyCopies().map { (name: $0.url.lastPathComponent, date: $0.made) }
        for name in Backup.toRemove(all) { try? fm.removeItem(at: backupFolder.appendingPathComponent(name)) }
    }

    /// The weekly copies on this iPhone, newest first.
    func weeklyCopies() -> [(url: URL, made: Date)] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "json" }.map { url in
            let made = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return (url, made)
        }.sorted { $0.made > $1.made }
    }

    // MARK: Backup reminder (since 1.8)

    private static let lastBackupKey = "lastBackup"
    private static let reminderLaterKey = "backupReminderLater"
    /// Changed to redraw the Train tab after Later or a backup.
    private(set) var reminderTick = 0

    /// The last backup kept outside the app: Back up now, or an automatic one.
    var lastBackup: Date? { defaults.object(forKey: Self.lastBackupKey) as? Date }

    private func noteBackup(_ date: Date = Date()) {
        defaults.set(date, forKey: Self.lastBackupKey)
        reminderTick += 1
    }

    /// True when there is something to lose and no backup for 14 days (UI tests: -backupdue).
    var backupReminderDue: Bool {
        _ = reminderTick
        if ProcessInfo.processInfo.arguments.contains("-backupdue") && lastBackup == nil
            && defaults.object(forKey: Self.reminderLaterKey) == nil { return true }
        let oldest = (gym.visits.map(\.date) + history.map(\.started)).min()
        return Backup.reminderDue(lastBackup: lastBackup, oldestData: oldest,
                                  later: defaults.object(forKey: Self.reminderLaterKey) as? Date, now: Date())
    }

    /// "Later": quiet for 3 days.
    func backupReminderLater() {
        defaults.set(Date(), forKey: Self.reminderLaterKey)
        reminderTick += 1
    }

    // MARK: Automatic backup (since 1.7)

    /// The folder chosen once (iCloud Drive or anywhere in Files); a bookmark keeps the permission.
    private static let autoKey = "autoBackupFolder"
    private static let autoLastKey = "autoBackupLast"
    private var defaults: UserDefaults { Self.store }
    /// The app's small settings; UI tests get a fresh, empty set each launch.
    private static let store: UserDefaults = {
        guard ProcessInfo.processInfo.arguments.contains("-uitest"), let d = UserDefaults(suiteName: "uitest") else { return .standard }
        d.removePersistentDomain(forName: "uitest")
        return d
    }()

    /// The chosen folder's name, or nil when automatic backup is off.
    var autoFolderName: String? { autoFolder()?.lastPathComponent }
    var autoLast: Date? { defaults.object(forKey: Self.autoLastKey) as? Date }
    /// Why the last automatic backup failed, shown in Backups.
    private(set) var autoProblem: String?

    private func autoFolder() -> URL? {
        guard let data = defaults.data(forKey: Self.autoKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Self.autoKey) }
        return url
    }

    /// Turns automatic backup on with this folder and makes the first backup at once.
    func chooseAutoFolder(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData() else {
            autoProblem = "That folder cannot be used. Choose another one."
            return
        }
        defaults.set(data, forKey: Self.autoKey)
        defaults.removeObject(forKey: Self.autoLastKey)
        autoBackupIfDue()
    }

    func stopAutoBackup() {
        defaults.removeObject(forKey: Self.autoKey)
        defaults.removeObject(forKey: Self.autoLastKey)
        autoProblem = nil
    }

    /// Once a day — at launch and when the app goes to the background — a backup in the chosen
    /// folder; only the newest 7 of the app's own backups there are kept.
    func autoBackupIfDue(now: Date = Date()) {
        guard let url = autoFolder(), Backup.dailyDue(last: autoLast, now: now) else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Backup.encode(makeBackup(at: now)),
              (try? data.write(to: url.appendingPathComponent(Backup.fileName(now)), options: .atomic)) != nil else {
            autoProblem = "The last automatic backup could not be saved in \(url.lastPathComponent)."
            return
        }
        autoProblem = nil
        defaults.set(now, forKey: Self.autoLastKey)
        noteBackup(now)
        let fm = FileManager.default
        let ours = ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("Workouts backup ") && $0.pathExtension == "json" }
            .map { (name: $0.lastPathComponent, date: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
        for name in Backup.toRemove(ours, keep: 7) { try? fm.removeItem(at: url.appendingPathComponent(name)) }
    }

    /// Puts a backup's data in place of today's. Today's files and photos are first kept aside in
    /// Documents/Before restore <date>, so a wrong restore can be undone; nothing is overwritten blindly.
    func restore(_ backup: Backup) throws {
        _ = try backup.contents()   // every file must read before anything changes
        let fm = FileManager.default
        let aside = folder.appendingPathComponent("Before restore \(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try fm.createDirectory(at: aside, withIntermediateDirectories: true)
        for name in Backup.fileNames where fm.fileExists(atPath: folder.appendingPathComponent(name).path) {
            try fm.copyItem(at: folder.appendingPathComponent(name), to: aside.appendingPathComponent(name))
        }
        if fm.fileExists(atPath: photoFolder.path) {
            try fm.copyItem(at: photoFolder, to: aside.appendingPathComponent("Photos", isDirectory: true))
        }
        // Then the backup's files and photos.
        for name in Backup.fileNames {
            let url = folder.appendingPathComponent(name)
            if let data = backup.files[name] {
                try data.write(to: url, options: .atomic)
            } else {
                try? fm.removeItem(at: url)
            }
        }
        try? fm.removeItem(at: photoFolder)
        try fm.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        for (name, data) in backup.photos where !name.contains("/") {
            try data.write(to: photoFolder.appendingPathComponent(name), options: .atomic)
        }
        load()
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
        // While Undo is offered, a deleted machine's or workout's photo must stay.
        guard !gymUnreadable, undoPoint == nil else { return }
        let inUse = WorkoutFile.photosInUse(workouts).union(gym.photosInUse)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? []
        for name in names where !inUse.contains(name) {
            try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name))
        }
    }
}
