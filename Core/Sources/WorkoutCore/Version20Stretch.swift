import Foundation

/// One stretch ready to be timed (since 2.0): from the library, from his own, or from an old list.
public struct StretchPick: Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    /// Seconds per side.
    public var seconds: Int
    /// 1 or 2.
    public var sides: Int
    /// The library id whose figure to draw; nil for his own stretches and old lists.
    public var figureID: String?
    /// His own photo (own stretch).
    public var photo: String?
    public var note: String

    public init(id: String, name: String, seconds: Int, sides: Int, figureID: String? = nil, photo: String? = nil, note: String = "") {
        self.id = id; self.name = name; self.seconds = min(600, max(5, seconds)); self.sides = sides == 2 ? 2 : 1
        self.figureID = figureID; self.photo = photo; self.note = note
    }

    /// "30 s each side" / "60 s"
    public var amount: String {
        "\(seconds) s" + (sides == 2 ? " each side" : "")
    }
}

public extension StretchBook {
    /// The After-gym list's equivalents in the library: what is ticked when there is no old list.
    static let defaultTicks = ["chest-door", "shoulder-cross", "hip-flexor", "hamstring-seated", "quad-standing", "childs-pose"]

    /// The book made from the old stretch list (GymLog.stretchID), once. The old Workout is only read.
    /// Names the library knows become library ids; the others become his own stretches with their
    /// hold time, note and photo. No list, none, or a list that is gone: the After-gym equivalents.
    static func migrated(stretchID: UUID?, workouts: [Workout]) -> StretchBook {
        var book = StretchBook()
        book.migratedFrom = stretchID
        let list = stretchID.flatMap { id in
            workouts.first { $0.id == id } ?? StretchRoutine.all.first { $0.id == id }?.workout()
        }
        guard let list else { book.ticked = defaultTicks; return book }
        for e in StretchTimer.choosable(list.exercises) {
            if let lib = StretchLibrary.alias(for: e.name) {
                if !book.ticked.contains(lib) { book.ticked.append(lib) }
            } else {
                let (secs, sides) = StretchTimer.hold(of: e.amount)
                let c = CustomStretch(name: e.name, seconds: secs, sides: sides, note: e.note, photo: e.photo)
                book.custom.append(c)
                book.ticked.append(c.id)
            }
        }
        return book
    }

    func custom(_ id: String) -> CustomStretch? { custom.first { $0.id == id } }

    /// Name of a library or own stretch.
    func name(of id: String) -> String? { StretchLibrary.item(id)?.name ?? custom(id)?.name }

    /// What to time for an id: his changed hold time wins over the library's.
    func pick(_ id: String) -> StretchPick? {
        if let c = custom(id) {
            return StretchPick(id: id, name: c.name, seconds: holds[id] ?? c.seconds, sides: c.sides, photo: c.photo, note: c.note)
        }
        guard let item = StretchLibrary.item(id) else { return nil }
        return StretchPick(id: id, name: item.name, seconds: holds[id] ?? item.seconds, sides: item.sides,
                           figureID: id, note: StretchLibrary.guide(id)?.note ?? "")
    }

    func picks(_ ids: [String]) -> [StretchPick] { ids.compactMap(pick) }

    mutating func setHold(_ id: String, seconds: Int) {
        let s = min(600, max(5, seconds))
        if let i = custom.firstIndex(where: { $0.id == id }) { custom[i].seconds = s; holds[id] = nil } else { holds[id] = s }
    }

    mutating func toggleFavourite(_ id: String) {
        if let i = favourites.firstIndex(of: id) { favourites.remove(at: i) } else { favourites.append(id) }
    }

    mutating func add(_ id: String) { if !ticked.contains(id) { ticked.append(id) } }
    mutating func remove(_ id: String) { ticked.removeAll { $0 == id } }

    mutating func save(custom c: CustomStretch) {
        if let i = custom.firstIndex(where: { $0.id == c.id }) { custom[i] = c } else { custom.append(c) }
    }

    /// An own stretch is gone from the list, favourites and holds too.
    mutating func delete(custom id: String) {
        custom.removeAll { $0.id == id }
        ticked.removeAll { $0 == id }
        favourites.removeAll { $0 == id }
        holds[id] = nil
    }
}

public extension GymLog {
    /// Takes over the old stretch list the first time (idempotent: a book that exists stays as it is).
    mutating func migrateStretchBook(workouts: [Workout]) {
        guard stretchBook == nil else { return }
        stretchBook = StretchBook.migrated(stretchID: stretchID, workouts: workouts)
    }

    /// The muscle group ids of the machines done in a visit, in the order first done. A group he made
    /// himself counts as chest, back, shoulders, arms, legs or core when its name says so.
    func trainedMuscles(in visit: GymVisit) -> [String] {
        var out: [String] = []
        for e in visit.entries {
            guard let m = machines.first(where: { $0.id == e.machineID }), let g = m.muscle,
                  let key = Self.muscleKey(g, groups: muscles), !out.contains(key) else { continue }
            out.append(key)
        }
        return out
    }

    static func muscleKey(_ id: String, groups: [MuscleGroup]) -> String? {
        let std = ["chest", "back", "shoulders", "arms", "legs", "core"]
        if std.contains(id) { return id }
        guard let name = groups.first(where: { $0.id == id })?.name.lowercased() else { return nil }
        let words: [(String, [String])] = [("chest", ["chest"]), ("back", ["back"]), ("shoulders", ["shoulder"]),
                                           ("arms", ["arm"]), ("legs", ["leg"]), ("core", ["core"])]
        return words.first { $0.1.contains { name.contains($0) } }?.0
    }

    /// "legs, back": the groups trained in the visit, in his words.
    func trainedWords(in visit: GymVisit) -> String {
        trainedMuscles(in: visit).map { key in
            (muscles.first { $0.id == key }?.name ?? key).lowercased()
        }.joined(separator: ", ")
    }

    /// Library stretches for the muscles trained in a visit, plus the finish ones; at most 12.
    func suggestedStretches(for visit: GymVisit?) -> [String] {
        guard let visit else { return [] }
        let trained = Set(trainedMuscles(in: visit))
        guard !trained.isEmpty else { return [] }
        let finish = StretchLibrary.stretches.filter { $0.area == .finish }.map(\.id)
        let matched = StretchLibrary.stretches.filter { $0.area != .finish && !trained.isDisjoint(with: $0.muscles) }.map(\.id)
        return Array(matched.prefix(12 - finish.count)) + finish
    }
}

public extension StretchTimer {
    /// Every phase of a list of picks, in order (since 2.0). Hold times and sides come from the picks.
    static func phases(for picks: [StretchPick]) -> [StretchPhase] {
        var out: [StretchPhase] = []
        for (i, p) in picks.enumerated() {
            let secs = p.seconds, sides = p.sides
            let first = i == 0 ? "First" : i == picks.count - 1 ? "Last one" : "Next"
            let each = sides == 2 ? "\(spokenSeconds(secs)) each side" : spokenSeconds(secs)
            func phase(_ k: StretchPhase.Kind, _ side: Int, _ s: Int, _ say: String) -> StretchPhase {
                StretchPhase(kind: k, index: i, name: p.name, side: side, sides: sides, seconds: s, spoken: say,
                             pickID: p.id, figureID: p.figureID)
            }
            out.append(phase(.ready, sides == 2 ? 1 : 0, readySeconds, "\(first): \(p.name). \(each). Get into position."))
            out.append(phase(.hold, sides == 2 ? 1 : 0, secs, sides == 2 ? "Hold. First side." : "Hold."))
            if sides == 2 {
                out.append(phase(.switchSides, 2, switchSeconds, "Switch sides."))
                out.append(phase(.hold, 2, secs, "Hold. Second side."))
            }
        }
        return out
    }

    static func spokenSeconds(_ seconds: Int) -> String {
        seconds % 60 == 0 && seconds >= 60 ? (seconds == 60 ? "one minute" : "\(seconds / 60) minutes") : "\(seconds) seconds"
    }

    /// The old list as picks (id = the exercise's id).
    static func picks(for exercises: [Exercise]) -> [StretchPick] {
        choosable(exercises).map { e in
            let (s, n) = hold(of: e.amount)
            return StretchPick(id: e.id.uuidString, name: e.name, seconds: s, sides: n, photo: e.photo, note: e.note)
        }
    }
}
