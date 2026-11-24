import Foundation
import UIKit
import WorkoutCore

/// The meeting point with iCloud (since 3.0): the same four data files and the photos, in the app's
/// own iCloud folder, joined with this device's by the rules in WorkoutCore's `SyncDoc`.
///
/// This device always keeps its own full copy in Documents. iCloud's files are only where the
/// devices meet: each meeting reads the iCloud file (and any conflict copies iCloud parked), joins
/// them with this device's data record by record, and writes the joined data to both sides. A file
/// that is missing, still downloading or unreadable is never taken for "empty".
@MainActor
final class CloudSync {
    nonisolated static let containerID = "iCloud.com.schabbauer.AMSWorkoutCompanion"
    private static let joinedKey = "iCloudJoined"

    private unowned let library: Library
    /// `<the app's iCloud folder>/Sync`; nil until iCloud is found (or when it is off).
    private var root: URL?
    private var looking = false
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var running = false
    private var again = false
    /// What was last joined per file — the iCloud file's date and this device's doc — to skip a meeting when neither moved.
    private var seen: [SyncFile: (cloud: Date, local: SyncDoc)] = [:]
    /// When this device and iCloud last held the same.
    private(set) var lastCurrent: Date?

    init(library: Library) {
        self.library = library
        observers.append(NotificationCenter.default.addObserver(forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.accountChanged() }
        })
    }

    /// Finds iCloud (the first time) and meets it. Safe to call often: at launch and whenever the app comes to the front.
    func start() {
        if root != nil {
            sync()
            return
        }
        guard !looking else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            library.setSync(.off)
            return
        }
        looking = true
        library.setSync(.working)
        Task.detached(priority: .utility) {
            // Asking for the folder can take a moment, so not on the main thread.
            let url = FileManager.default.url(forUbiquityContainerIdentifier: CloudSync.containerID)
            await MainActor.run { self.found(url) }
        }
    }

    private func found(_ container: URL?) {
        looking = false
        guard let container else {
            library.setSync(.off)
            return
        }
        // Before this device's data meets iCloud for the first time: one backup of everything here.
        if !UserDefaults.standard.bool(forKey: Self.joinedKey) {
            guard library.keepBeforeICloud() else {
                library.setSync(.problem("No room for a backup before iCloud"))
                return
            }
            UserDefaults.standard.set(true, forKey: Self.joinedKey)
        }
        let folder = container.appendingPathComponent("Sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder.appendingPathComponent("Photos", isDirectory: true), withIntermediateDirectories: true)
        root = folder
        watch()
        sync()
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            // A quiet check every half minute while the app is open, in case iCloud's own notice was missed.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if UIApplication.shared.applicationState == .active { self?.sync() }
            }
        }
    }

    private func accountChanged() {
        query?.stop()
        query = nil
        heartbeat?.cancel()
        root = nil
        seen = [:]
        start()
    }

    /// A change on this device: meet iCloud a moment later (several quick changes go up together).
    func localChanged() {
        guard root != nil else { return }
        schedule(after: 1.5)
    }

    /// "Sync now" on Settings → iCloud.
    func syncNow() {
        seen = [:]
        start()
    }

    private func schedule(after seconds: Double) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.sync()
        }
    }

    // MARK: Watching iCloud's folder

    private func watch() {
        guard query == nil else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        q.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: q, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.cloudMoved() }
            })
        }
        query = q
        q.start()
    }

    /// iCloud says something in the folder is new: fetch what is not here yet, then meet.
    private func cloudMoved() {
        guard let q = query else { return }
        q.disableUpdates()
        for case let item as NSMetadataItem in q.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
                  status != NSMetadataUbiquitousItemDownloadingStatusCurrent else { continue }
            // Only the data files and photos that are in use are fetched here; the photo pass fetches the rest it needs.
            if SyncFile(rawValue: url.lastPathComponent) != nil { try? FileManager.default.startDownloadingUbiquitousItem(at: url) }
        }
        q.enableUpdates()
        schedule(after: 0.5)
    }

    // MARK: One meeting

    func sync() {
        guard root != nil else { return }
        if running {
            again = true
            return
        }
        running = true
        Task { [weak self] in
            await self?.meet()
            guard let self else { return }
            self.running = false
            if self.again {
                self.again = false
                self.schedule(after: 0.3)
            }
        }
    }

    private func meet() async {
        guard let root else { return }
        // While "Undo" is offered, the data on screen may still jump back: meet when the offer is over.
        if library.undoPoint != nil {
            schedule(after: 3)
            return
        }
        if case .current = library.syncStatus {} else { library.setSync(.working) }
        var settled = true
        var problem: String?
        for file in SyncFile.allCases {
            guard library.doc(file) != nil else {
                // This file cannot be joined safely on this device (see Library.docs): it stays here, untouched.
                problem = "Part of the data on this device could not be read"
                continue
            }
            let url = root.appendingPathComponent(file.rawValue)
            let read = await Task.detached(priority: .utility) { CloudSync.read(url) }.value
            var cloud: [SyncDoc] = []
            var fileThere = false
            var merged: [Data] = []
            var date = Date.distantPast
            switch read {
            case .waiting:
                settled = false
                continue
            case .absent:
                break
            case .found(let data, let conflicts, let modified):
                date = modified
                if let last = seen[file], last.cloud == modified, conflicts.isEmpty, last.local == library.doc(file) { continue }
                if let doc = try? file.doc(from: data).doc {
                    cloud.append(doc)
                    fileThere = true
                } else {
                    // A file in iCloud that cannot be read: its bytes are kept here before anything is written over it.
                    park(data, as: file)
                }
                for bytes in conflicts {
                    if let doc = try? file.doc(from: bytes).doc {
                        cloud.append(doc)
                        merged.append(bytes)
                    }
                }
            }
            // From here to the end of this file's turn nothing waits, so this device's data cannot change underneath.
            guard let local = library.doc(file) else { continue }
            let join = SyncJoin.join(file, local: local, cloud: cloud, cloudFileThere: fileThere)
            if join.newerApp {
                problem = "Update Workouts on this device to sync"
                continue
            }
            if join.changesLocal, !library.apply(file, join.doc) {
                problem = "Something from iCloud could not be read"
                continue
            }
            if join.changesCloud {
                guard let bytes = try? file.data(from: join.doc) else { continue }
                let done = await Task.detached(priority: .utility) { CloudSync.write(bytes, to: url, resolving: merged) }.value
                guard let written = done else {
                    settled = false
                    continue
                }
                date = written
            }
            if let now = library.doc(file) { seen[file] = (date, now) }
        }
        if let names = library.photosInUse {
            let local = library.photoFolder
            let cloud = root.appendingPathComponent("Photos", isDirectory: true)
            let result = await Task.detached(priority: .utility) { CloudSync.photos(inUse: names, local: local, cloud: cloud) }.value
            if result.arrived > 0 { library.photosArrived() }
            if result.waiting > 0 {
                settled = false
                schedule(after: 5)
            }
        }
        if let problem {
            library.setSync(.problem(problem))
        } else if settled {
            lastCurrent = Date()
            library.setSync(.current(Date()))
        } else {
            library.setSync(.working)
        }
    }

    /// Keeps the bytes of an unreadable iCloud file on this device (Documents/From iCloud unreadable).
    private func park(_ data: Data, as file: SyncFile) {
        let folder = library.folder.appendingPathComponent("From iCloud unreadable", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent("\(Int(Date().timeIntervalSince1970)) \(file.rawValue)"), options: .atomic)
    }

    // MARK: Disk work, off the main thread

    enum CloudRead: Sendable {
        /// The file is not in iCloud's folder (as far as this device knows).
        case absent
        /// It is there but not on this device yet; the download has been asked for.
        case waiting
        /// The file, the conflict copies iCloud parked beside it, and the file's date.
        case found(Data, conflicts: [Data], modified: Date)
    }

    nonisolated static func read(_ url: URL) -> CloudRead {
        let fm = FileManager.default
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        if !fm.fileExists(atPath: url.path) {
            guard fm.fileExists(atPath: placeholder.path) else { return .absent }
            try? fm.startDownloadingUbiquitousItem(at: url)
            return .waiting
        }
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .contentModificationDateKey])
        if values?.ubiquitousItemDownloadingStatus == .notDownloaded {
            try? fm.startDownloadingUbiquitousItem(at: url)
            return .waiting
        }
        // A newer version exists in iCloud than the one here: ask for it; this meeting works with what is here.
        if values?.ubiquitousItemDownloadingStatus == .downloaded { try? fm.startDownloadingUbiquitousItem(at: url) }
        var data: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { at in
            data = try? Data(contentsOf: at)
        }
        guard let data else { return .waiting }
        var conflicts: [Data] = []
        for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] {
            if let bytes = try? Data(contentsOf: version.url) { conflicts.append(bytes) }
        }
        return .found(data, conflicts: conflicts, modified: values?.contentModificationDate ?? Date())
    }

    /// Writes the joined file and clears the conflict copies that were joined into it — only those:
    /// a conflict copy that arrived meanwhile stays for the next meeting. Returns the file's new date.
    nonisolated static func write(_ data: Data, to url: URL, resolving merged: [Data]) -> Date? {
        var ok = false
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error) { at in
            ok = (try? data.write(to: at, options: .atomic)) != nil
        }
        guard ok else { return nil }
        for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] {
            guard let bytes = try? Data(contentsOf: version.url), merged.contains(bytes) else { continue }
            version.isResolved = true
            try? version.remove()
        }
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
    }

    /// Photos: every photo in use goes up once, every photo in use that is missing here comes down.
    /// A photo nobody uses any more leaves iCloud only after 30 days, so a record that is still on
    /// its way from another device never finds its photo gone.
    nonisolated static func photos(inUse: Set<String>, local: URL, cloud: URL) -> (arrived: Int, waiting: Int) {
        let fm = FileManager.default
        try? fm.createDirectory(at: cloud, withIntermediateDirectories: true)
        let here = Set((try? fm.contentsOfDirectory(atPath: local.path)) ?? [])
        var there = Set<String>()       // in iCloud and on this device
        var notYet = Set<String>()      // in iCloud, not downloaded to this device
        for name in (try? fm.contentsOfDirectory(atPath: cloud.path)) ?? [] {
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                notYet.insert(String(name.dropFirst().dropLast(7)))
            } else if (try? cloud.appendingPathComponent(name).resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
                        .ubiquitousItemDownloadingStatus == .notDownloaded {
                notYet.insert(name)
            } else {
                there.insert(name)
            }
        }
        var arrived = 0, waiting = 0
        for name in inUse where !name.contains("/") {
            let mine = local.appendingPathComponent(name), theirs = cloud.appendingPathComponent(name)
            if here.contains(name) {
                guard !there.contains(name), !notYet.contains(name) else { continue }
                var error: NSError?
                NSFileCoordinator().coordinate(writingItemAt: theirs, options: [], error: &error) { at in
                    try? fm.copyItem(at: mine, to: at)
                }
            } else if there.contains(name) {
                var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: theirs, options: [], error: &error) { at in
                    if let bytes = try? Data(contentsOf: at), (try? bytes.write(to: mine, options: .atomic)) != nil { arrived += 1 }
                }
            } else if notYet.contains(name) {
                try? fm.startDownloadingUbiquitousItem(at: theirs)
                waiting += 1
            }
        }
        let old = Date().addingTimeInterval(-30 * 24 * 3600)
        for name in there where !inUse.contains(name) {
            let url = cloud.appendingPathComponent(name)
            guard let made = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, made < old else { continue }
            var error: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error) { at in
                try? fm.removeItem(at: at)
            }
        }
        return (arrived, waiting)
    }
}
