import SwiftUI
import UIKit
import WorkoutCore

/// The workouts on this iPhone: one JSON file and a folder of photos in Documents.
@MainActor
@Observable
final class Library {
    private(set) var workouts: [Workout] = []
    let folder: URL

    private var file: URL { folder.appendingPathComponent("workouts.json") }
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
    }

    /// Documents on the iPhone; a fresh, empty folder for UI tests.
    static func launch() -> Library {
        let fm = FileManager.default
        if ProcessInfo.processInfo.arguments.contains("-uitest") {
            let dir = fm.temporaryDirectory.appendingPathComponent("uitest", isDirectory: true)
            try? fm.removeItem(at: dir)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
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
        // Photos no workout uses any more (replaced, removed, deleted) go.
        let inUse = WorkoutFile.photosInUse(workouts)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? []
        for name in names where !inUse.contains(name) {
            try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name))
        }
    }
}
