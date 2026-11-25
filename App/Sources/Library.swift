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
    /// How this device stands with iCloud (since 3.0); the side list's dot and Settings → iCloud show it.
    private(set) var syncStatus: SyncStatus = .off

    /// The sound choices and his own interval presets (since 3.0 in settings.json, so they travel too).
    private(set) var settings = SharedSettings()
    /// Each data file taken apart, with its change marks, as last written (since 3.0). Nil for a file
    /// that cannot be joined safely (unreadable, or two records with one id): that file stays on this device.
    private var docs: [SyncFile: SyncDoc] = [:]
    /// Which device this is when data from before 3.0 meets: Mac 1, iPad 2, iPhone 3 — the iPhone's stays.
    let rank: Int
    /// The meeting point with iCloud; nil in UI tests.
    var cloud: CloudSync?
    /// Goes up when a photo arrived from another device, so pictures on screen are drawn again.
    private(set) var photoTick = 0
    /// The library the sound settings read from (they are asked for from places without a library at hand).
    static weak var current: Library?

    private var file: URL { folder.appendingPathComponent("workouts.json") }
    private var gymFile: URL { folder.appendingPathComponent("gym.json") }
    private var historyFile: URL { folder.appendingPathComponent("history.json") }
    private var settingsFile: URL { folder.appendingPathComponent(SettingsFile.name) }
    var photoFolder: URL { folder.appendingPathComponent("Photos", isDirectory: true) }

    init(folder: URL, rank: Int? = nil) {
        self.folder = folder
        self.rank = rank ?? Library.deviceRank
        load()
        Library.current = self
    }

    static var deviceRank: Int {
        if ProcessInfo.processInfo.isiOSAppOnMac { return 1 }
        return UIDevice.current.userInterfaceIdiom == .pad ? 2 : 3
    }

    /// Reads the three files; at launch and again after a restore.
    private func load() {
        let fm = FileManager.default
        try? fm.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        workouts = []
        gym = GymLog()
        history = []
        workoutsUnreadable = false
        gymUnreadable = false
        historyUnreadable = false
        docs = [:]
        if let data = try? Data(contentsOf: file) {
            if let list = try? WorkoutFile.decode(data) {
                workouts = list
                docs[.workouts] = (try? SyncFile.workouts.doc(from: data))?.doc.baselined(rank: rank)
            } else {
                // Never overwrite a file we cannot read: keep it aside first, and save nothing over it (1.21).
                workoutsUnreadable = true
                let aside = folder.appendingPathComponent("workouts-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: file, to: aside)
            }
        } else {
            // Saved below, once the gym log is read: saving now would tidy away every gym photo,
            // since the gym log is still empty here (found 3 Nov 2026 replaying his backup).
            workouts = Starters.all
            needsFirstSave = true
        }
        if let data = try? Data(contentsOf: gymFile) {
            if let log = try? GymFile.decode(data) {
                gym = log
                docs[.gym] = (try? SyncFile.gym.doc(from: data))?.doc.baselined(rank: rank)
            } else {
                gymUnreadable = true
                let aside = folder.appendingPathComponent("gym-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: gymFile, to: aside)
            }
        }
        if let data = try? Data(contentsOf: historyFile) {
            if let list = try? HistoryFile.decode(data) {
                history = list
                docs[.history] = (try? SyncFile.history.doc(from: data))?.doc.baselined(rank: rank)
            } else {
                historyUnreadable = true
                let aside = folder.appendingPathComponent("history-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: historyFile, to: aside)
            }
        }
        // A file that is not there yet starts as an empty doc from before sync: whatever is saved into
        // it first (the starter workouts, a first gym) counts as "from before 3.0", not as a change made now.
        if !fm.fileExists(atPath: gymFile.path) { docs[.gym] = SyncDoc() }
        if !fm.fileExists(atPath: historyFile.path) { docs[.history] = HistoryFile.doc([])?.baselined(rank: rank) }
        loadSettings()
        if needsFirstSave {
            needsFirstSave = false
            docs[.workouts] = WorkoutFile.doc(workouts)?.baselined(rank: rank)
            persist()
        }
    }

    /// settings.json; the first time, the sounds and presets move over from the phone's small settings store.
    private func loadSettings() {
        settingsUnreadable = false
        if let data = try? Data(contentsOf: settingsFile) {
            if let read = try? SettingsFile.read(data) {
                settings = read.settings
                docs[.settings] = (try? SyncFile.settings.doc(from: data))?.doc.baselined(rank: rank)
            } else {
                settingsUnreadable = true
                let aside = folder.appendingPathComponent("settings-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: settingsFile, to: aside)
            }
            return
        }
        var moved = SharedSettings()
        let old = UserDefaults.standard
        if !ProcessInfo.processInfo.arguments.contains("-uitest") {
            if let data = old.data(forKey: "sounds"), let c = try? JSONDecoder().decode(SoundChoice.self, from: data) { moved.sounds = c }
            if let data = old.data(forKey: "intervalPresets"),
               let list = try? JSONDecoder().decode([IntervalPreset].self, from: data) { moved.presets = list }
        }
        settings = moved
        docs[.settings] = SettingsFile.doc(moved)?.baselined(rank: rank)
        if let data = try? SettingsFile.encode(moved, marks: docs[.settings]?.marks) { try? data.write(to: settingsFile, options: .atomic) }
    }

    private var settingsUnreadable = false

    func setSounds(_ sounds: SoundChoice) {
        settings.sounds = sounds
        persistSettings()
    }

    func setPresets(_ presets: [IntervalPreset]) {
        settings.presets = presets
        persistSettings()
    }

    /// The starter workouts still have to be written (a first launch, or a backup without workouts).
    private var needsFirstSave = false

    /// True when workouts.json could not be read: it is kept aside and never overwritten (since 1.21 —
    /// until then the next change saved an empty list over it and tidied the workouts' photos away).
    private var workoutsUnreadable = false

    /// What the red note at the top of Train says when a file could not be read (since 1.21); nil = all read.
    var unreadableNote: String? {
        if workoutsUnreadable { return "Your workouts could not be read" }
        if gymUnreadable { return "Your gym log could not be read" }
        if historyUnreadable { return "Your history could not be read" }
        return nil
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
            // -unreadable (1.21 test): a workouts file that cannot be read.
            if ProcessInfo.processInfo.arguments.contains("-unreadable") {
                try? Data("not a workouts file".utf8).write(to: dir.appendingPathComponent("workouts.json"))
            }
            if ProcessInfo.processInfo.arguments.contains("-gymdemo") {
                var demo = GymLog.demo()
                // -gymextras (1.11): muscle groups on the demo machines, six more machines (so the search field
                // shows) and Chest press + Lat pulldown as a superset.
                if ProcessInfo.processInfo.arguments.contains("-gymextras") { demo.addExtras() }
                // -tallphotos: an upright photo on every machine, like his home-gym photos (1.9.2 test).
                if ProcessInfo.processInfo.arguments.contains("-tallphotos") {
                    let photos = dir.appendingPathComponent("Photos", isDirectory: true)
                    try? fm.createDirectory(at: photos, withIntermediateDirectories: true)
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let tall = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: format).image { c in
                        UIColor.systemTeal.setFill()
                        c.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
                    }
                    if let jpeg = tall.jpegData(compressionQuality: 0.6) {
                        try? jpeg.write(to: photos.appendingPathComponent("tall.jpg"))
                        for i in demo.machines.indices { demo.machines[i].photo = "tall.jpg" }
                        if let first = demo.gyms.first { demo.setPhoto(gym: first.id, "tall.jpg") }
                    }
                }
                if let data = try? GymFile.encode(demo) { try? data.write(to: dir.appendingPathComponent("gym.json")) }
            }
            // UI tests can start from a given gym file (to replay a problem with real data on the Mac only).
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-gymfile"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                try? fm.copyItem(atPath: ProcessInfo.processInfo.arguments[i + 1], toPath: dir.appendingPathComponent("gym.json").path)
            }
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-photosdir"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                try? fm.copyItem(atPath: ProcessInfo.processInfo.arguments[i + 1], toPath: dir.appendingPathComponent("Photos").path)
            }
            return Library(folder: dir)
        }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let library = Library(folder: docs)
        library.weeklyBackup()
        library.autoBackupIfDue()
        // 3.0: the meeting point with iCloud; it starts when the first window is up.
        library.cloud = CloudSync(library: library)
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
        // A finished session new, changed or gone: the Garmin Board's file follows (since 1.24).
        let finished: (GymLog) -> [GymVisit] = { $0.visits.filter { $0.finished != nil } }
        let boardChanged = finished(log) != finished(gym)
        gym = log
        persistGym()
        if boardChanged { writeBoardFile() }
        // The session on the lock screen follows every change (since 1.23).
        SessionLive.sync(gym)
    }

    // MARK: History

    func record(_ r: SessionRecord) {
        history.append(r)
        persistHistory()
        // 3.1: a finished Sets & reps workout is noted for AMS Triathlon Training (this device only).
        TrainingLink.add(TrainingNotes.note(for: r))
    }

    /// 3.1: a finished gym session is noted for AMS Triathlon Training. Called where Finish is tapped on
    /// this device, never for a session that arrives from another device.
    func noteFinished(visit id: UUID) {
        guard let v = gym.visits.first(where: { $0.id == id }), v.setCount > 0 else { return }
        TrainingLink.add(TrainingNotes.note(for: v))
    }

    /// 3.1: Undo Finish or Discard session takes the note back.
    func forgetNote(visit id: UUID) { TrainingLink.remove(id: id.uuidString) }

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
        _ = photoTick   // a photo that arrives from another device redraws whoever asked for it
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
        guard force || (unreadableNote == nil && Backup.weeklyDue(newest: copies.first?.made, now: now)),
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
        // While a file cannot be read, no automatic backup: it would push a good one out of the newest 7 (1.21).
        guard unreadableNote == nil, let url = autoFolder(), Backup.dailyDue(last: autoLast, now: now) else { return }
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

    // MARK: Garmin Board link (since 1.24)

    private static let boardKey = "boardFolder"
    private static let boardLastKey = "boardLast"

    /// The folder chosen for the Garmin Board's file, or nil when nothing is shared.
    var boardFolderName: String? { boardFolder()?.lastPathComponent }
    var boardLast: Date? { defaults.object(forKey: Self.boardLastKey) as? Date }
    /// Why the last write failed, shown on the Garmin Board page.
    private(set) var boardProblem: String?

    private func boardFolder() -> URL? {
        guard let data = defaults.data(forKey: Self.boardKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Self.boardKey) }
        return url
    }

    /// Shares the finished sessions into this folder from now on, and writes the file at once.
    func chooseBoardFolder(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData() else {
            boardProblem = "That folder cannot be used. Choose another one."
            return
        }
        defaults.set(data, forKey: Self.boardKey)
        writeBoardFile()
    }

    /// Forgets the folder; the file already there stays.
    func stopBoardLink() {
        defaults.removeObject(forKey: Self.boardKey)
        defaults.removeObject(forKey: Self.boardLastKey)
        boardProblem = nil
    }

    /// Writes "Workout Companion sessions.json" into the chosen folder: the last 60 finished sessions.
    /// Nothing is written without a chosen folder, or while the gym file cannot be read.
    func writeBoardFile(now: Date = Date()) {
        guard unreadableNote == nil, let url = boardFolder() else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? gym.boardFile(now: now).encoded(),
              (try? data.write(to: url.appendingPathComponent(BoardFile.name), options: .atomic)) != nil else {
            boardProblem = "The file could not be written to \(url.lastPathComponent). Is iCloud Drive on, and the folder still there?"
            return
        }
        boardProblem = nil
        defaults.set(now, forKey: Self.boardLastKey)
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
        // Then the backup's files and photos — all or nothing (1.21): a failure leaves today's data in place.
        let before = docs
        try backup.install(in: folder)
        load()
        // With sync (3.0): a restore is a change made now, on this device. The marks carry on from just
        // before it, so everything the backup puts back or takes away counts as changed or deleted now
        // and reaches the other devices — instead of being undone by them at the next meeting.
        for f in SyncFile.allCases { if let old = before[f] { docs[f] = old } }
        persist()
        persistGym()
        persistHistory()
        persistSettings()
    }

    // MARK: Saving

    /// Brings the file's doc and marks up to date with the data as it is now (3.0): what changed is
    /// marked changed now, what is gone is marked deleted. Returns the marks to write into the file.
    private func mark(_ f: SyncFile, _ fresh: SyncDoc?) -> SyncMarks? {
        guard let fresh, let old = docs[f] else {
            docs[f] = nil
            return nil
        }
        // A file's very first contents on this device count as "from before sync", not as changes made now.
        let blank = old.records.isEmpty && old.marks.changed.isEmpty && old.marks.gone.isEmpty
        let doc = blank ? fresh.baselined(rank: rank) : fresh.stamped(after: old)
        docs[f] = doc
        return doc.marks
    }

    private func persist() {
        guard !workoutsUnreadable else { return }
        let marks = mark(.workouts, WorkoutFile.doc(workouts))
        guard let data = try? WorkoutFile.encode(workouts, marks: marks) else { return }
        try? data.write(to: file, options: .atomic)
        removeUnusedPhotos()
        cloud?.localChanged()
    }

    private func persistGym() {
        guard !gymUnreadable else { return }
        let marks = mark(.gym, GymFile.doc(gym))
        guard let data = try? GymFile.encode(gym, marks: marks) else { return }
        try? data.write(to: gymFile, options: .atomic)
        removeUnusedPhotos()
        cloud?.localChanged()
    }

    private func persistHistory() {
        guard !historyUnreadable else { return }
        let marks = mark(.history, HistoryFile.doc(history))
        guard let data = try? HistoryFile.encode(history, marks: marks) else { return }
        try? data.write(to: historyFile, options: .atomic)
        cloud?.localChanged()
    }

    private func persistSettings() {
        guard !settingsUnreadable else { return }
        let marks = mark(.settings, SettingsFile.doc(settings))
        guard let data = try? SettingsFile.encode(settings, marks: marks) else { return }
        try? data.write(to: settingsFile, options: .atomic)
        cloud?.localChanged()
    }

    // MARK: iCloud (since 3.0)

    func setSync(_ status: SyncStatus) {
        if syncStatus != status { syncStatus = status }
    }

    /// This device's data for one file, ready to be joined; nil when it must stay out of the meeting.
    func doc(_ f: SyncFile) -> SyncDoc? { docs[f] }

    /// Puts joined data in place of this device's — only when every record in it reads back.
    @discardableResult
    func apply(_ f: SyncFile, _ doc: SyncDoc) -> Bool {
        guard docs[f] != nil, f.holds(doc), let data = try? f.data(from: doc) else { return false }
        let url: URL
        switch f {
        case .workouts:
            workouts = WorkoutFile.workouts(from: doc)
            url = file
        case .gym:
            let finished: (GymLog) -> [GymVisit] = { $0.visits.filter { $0.finished != nil } }
            let log = GymFile.log(from: doc)
            let boardChanged = finished(log) != finished(gym)
            gym = log
            url = gymFile
            if boardChanged { writeBoardFile() }
            SessionLive.sync(gym)
            GymNudge.sync(gym)
        case .history:
            history = HistoryFile.records(from: doc)
            url = historyFile
        case .settings:
            settings = SettingsFile.settings(from: doc)
            url = settingsFile
            Cues.shared.reload()
        }
        docs[f] = doc
        try? data.write(to: url, options: .atomic)
        if f == .gym {
            // A gym log always has a gym and a chosen gym that exists.
            var whole = gym
            whole.ensureGym()
            if whole != gym {
                gym = whole
                persistGym()
            }
        }
        if f == .workouts || f == .gym { removeUnusedPhotos() }
        return true
    }

    /// Every photo the data names; nil while a file is unreadable (then nobody may tidy photos).
    var photosInUse: Set<String>? {
        guard !gymUnreadable, !workoutsUnreadable else { return nil }
        return WorkoutFile.photosInUse(workouts).union(gym.photosInUse)
    }

    func photosArrived() { photoTick += 1 }

    /// The copy made once, just before this device first meets iCloud: Documents/Before iCloud.
    var beforeICloudFolder: URL { folder.appendingPathComponent("Before iCloud", isDirectory: true) }

    /// Keeps everything as it is on this device right now in one backup file, before the first join.
    /// True when the copy is there (or there was nothing to keep).
    func keepBeforeICloud(now: Date = Date()) -> Bool {
        let fm = FileManager.default
        guard !workouts.isEmpty || !gym.machines.isEmpty || !gym.visits.isEmpty || !history.isEmpty else { return true }
        try? fm.createDirectory(at: beforeICloudFolder, withIntermediateDirectories: true)
        guard let data = try? Backup.encode(makeBackup(at: now)) else { return false }
        return (try? data.write(to: beforeICloudFolder.appendingPathComponent(Backup.fileName(now)), options: .atomic)) != nil
    }

    /// The copies from before iCloud on this device, newest first.
    func beforeICloudCopies() -> [(url: URL, made: Date)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: beforeICloudFolder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "json" }.map { url in
            (url, (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
        }.sorted { $0.made > $1.made }
    }

    /// Photos no workout or machine uses any more (replaced, removed, deleted) go.
    private func removeUnusedPhotos() {
        // With an unreadable gym or workouts file we cannot know which photos they use: keep them all.
        // While Undo is offered, a deleted machine's or workout's photo must stay.
        guard !gymUnreadable, !workoutsUnreadable, undoPoint == nil else { return }
        let inUse = WorkoutFile.photosInUse(workouts).union(gym.photosInUse)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? []
        for name in names where !inUse.contains(name) {
            try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name))
        }
    }
}
