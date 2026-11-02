import Foundation

/// The three kinds of workout the app runs.
public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
    /// Sets of one exercise with a rest between them — push-ups 5 × 20.
    case reps
    /// A list of exercises ticked off one by one — the doctor's exercises.
    case checklist
    /// Work and rest rounds against the clock.
    case intervals

    public var title: String {
        switch self {
        case .reps: return "Sets & reps"
        case .checklist: return "Exercise list"
        case .intervals: return "Interval timer"
        }
    }

    public var blurb: String {
        switch self {
        case .reps: return "One exercise in sets, with a rest timer between them."
        case .checklist: return "Exercises with a note and a photo, ticked off one by one."
        case .intervals: return "Work and rest rounds, called out loud."
        }
    }

    /// SF Symbol shown on the workout's tile.
    public var symbol: String {
        switch self {
        case .reps: return "figure.strengthtraining.traditional"
        case .checklist: return "checklist"
        case .intervals: return "timer"
        }
    }

    /// The colour a new workout of this kind starts with (his WET colours).
    public var defaultColour: String {
        switch self {
        case .reps: return "orange"
        case .checklist: return "pink"
        case .intervals: return "green"
        }
    }
}

/// One exercise on an exercise list.
public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Free text: "3 × 10", "30 s each side".
    public var amount: String
    public var note: String
    /// File name of the photo in the app's photo folder.
    public var photo: String?

    public init(id: UUID = UUID(), name: String = "", amount: String = "", note: String = "", photo: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.note = note
        self.photo = photo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        amount = try c.decodeIfPresent(String.self, forKey: .amount) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
    }
}

/// A workout. Every kind keeps all fields, so switching the kind in the editor
/// and back loses nothing.
public struct Workout: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: WorkoutKind
    /// A key in `Palette`.
    public var colour: String
    // Sets & reps
    public var sets: Int
    public var reps: Int
    public var restSeconds: Int
    // Interval timer
    public var rounds: Int
    public var workSeconds: Int
    public var offSeconds: Int
    // Exercise list
    public var exercises: [Exercise]

    public init(
        id: UUID = UUID(), name: String = "", kind: WorkoutKind, colour: String? = nil,
        sets: Int = 5, reps: Int = 10, restSeconds: Int = 90,
        rounds: Int = 8, workSeconds: Int = 40, offSeconds: Int = 20,
        exercises: [Exercise] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.colour = colour ?? kind.defaultColour
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.workSeconds = workSeconds
        self.offSeconds = offSeconds
        self.exercises = exercises
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decodeIfPresent(WorkoutKind.self, forKey: .kind) ?? .reps
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
            kind: kind,
            colour: try c.decodeIfPresent(String.self, forKey: .colour),
            sets: try c.decodeIfPresent(Int.self, forKey: .sets) ?? 5,
            reps: try c.decodeIfPresent(Int.self, forKey: .reps) ?? 10,
            restSeconds: try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90,
            rounds: try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 8,
            workSeconds: try c.decodeIfPresent(Int.self, forKey: .workSeconds) ?? 40,
            offSeconds: try c.decodeIfPresent(Int.self, forKey: .offSeconds) ?? 20,
            exercises: try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        )
    }

    /// Total time of an interval workout, in seconds (no get-ready).
    public var intervalTotal: Int {
        rounds * workSeconds + max(0, rounds - 1) * offSeconds
    }

    /// One line under the name on the home screen.
    public var summary: String {
        switch kind {
        case .reps:
            let rest = restSeconds > 0 ? " · rest \(Clock.text(restSeconds))" : ""
            return "\(sets) × \(reps)\(rest)"
        case .intervals:
            let off = offSeconds > 0 ? " / \(Clock.text(offSeconds)) rest" : ""
            return "\(rounds) × \(Clock.text(workSeconds)) work\(off) · \(Clock.text(intervalTotal))"
        case .checklist:
            switch exercises.count {
            case 0: return "No exercises yet"
            case 1: return "1 exercise"
            default: return "\(exercises.count) exercises"
            }
        }
    }
}

public enum Clock {
    /// 90 → "1:30", 5 → "0:05", 3725 → "1:02:05".
    public static func text(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// The ready-made workouts a fresh install starts with.
public enum Starters {
    public static var all: [Workout] {
        [
            Workout(name: "Push-ups", kind: .reps, sets: 5, reps: 20, restSeconds: 90),
            Workout(name: "Intervals", kind: .intervals, rounds: 8, workSeconds: 40, offSeconds: 20),
            Workout(name: "Doctor's exercises", kind: .checklist),
        ]
    }
}

/// The file the workouts are kept in: `{"version": 1, "workouts": [...]}`.
public enum WorkoutFile {
    struct Envelope: Codable {
        var version: Int
        var workouts: [Workout]
    }

    public static func encode(_ workouts: [Workout]) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(Envelope(version: 1, workouts: workouts))
    }

    public static func decode(_ data: Data) throws -> [Workout] {
        try JSONDecoder().decode(Envelope.self, from: data).workouts
    }

    /// Photo file names the workouts still use — anything else in the photo folder can go.
    public static func photosInUse(_ workouts: [Workout]) -> Set<String> {
        Set(workouts.flatMap { $0.exercises.compactMap(\.photo) })
    }
}
