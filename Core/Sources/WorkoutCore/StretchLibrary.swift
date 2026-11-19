import Foundation

/// Body areas of the stretch library (since 2.0), in the order shown.
public enum StretchArea: String, Codable, CaseIterable, Sendable {
    case neck, arms, back, hips, legs, finish
    /// Warm-up moves (not a stretch area in the chooser).
    case warm

    public var title: String {
        switch self {
        case .neck: "Neck and shoulders"
        case .arms: "Arms"
        case .back: "Back and core"
        case .hips: "Hips and glutes"
        case .legs: "Legs"
        case .finish: "Finish"
        case .warm: "Warm-up moves"
        }
    }
}

/// One stretch or warm-up move of the library (since 2.0). The id is fixed forever: it names the
/// picture (FigureData) and is what StretchBook remembers.
public struct StretchItem: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let area: StretchArea
    /// MuscleGroup ids it suits (chest, back, shoulders, arms, legs, core) — for "Suggested for today".
    public let muscles: [String]
    /// Seconds per side (warm-up moves: seconds per move).
    public let seconds: Int
    /// 1 or 2.
    public let sides: Int

    public init(_ id: String, _ name: String, _ area: StretchArea, _ muscles: [String], _ seconds: Int, sides: Int) {
        self.id = id; self.name = name; self.area = area; self.muscles = muscles; self.seconds = seconds; self.sides = sides
    }

    /// The figure has the same id.
    public var figure: String { id }
}

/// The library: 30 stretches and 10 warm-up moves (since 2.0). Ids, names, areas and times live here;
/// the guide words (steps, where you feel it, careful) live in StretchLibraryGuides.swift.
public enum StretchLibrary {
    public static let stretches: [StretchItem] = [
        StretchItem("neck-side", "Neck side tilt", .neck, ["shoulders"], 20, sides: 2),
        StretchItem("neck-forward", "Neck forward tilt", .neck, ["shoulders", "back"], 20, sides: 1),
        StretchItem("shoulder-cross", "Shoulder across the body", .neck, ["shoulders"], 30, sides: 2),
        StretchItem("triceps-overhead", "Triceps overhead", .neck, ["arms", "shoulders"], 30, sides: 2),
        StretchItem("chest-door", "Chest in a doorway", .neck, ["chest", "shoulders"], 30, sides: 2),
        StretchItem("thread-needle", "Thread the needle", .neck, ["back", "shoulders"], 30, sides: 2),

        StretchItem("wrist-forearm", "Wrist and forearm", .arms, ["arms"], 20, sides: 2),
        StretchItem("lat-bar", "Lat stretch at a bar", .arms, ["back", "arms"], 30, sides: 2),
        StretchItem("biceps-wall", "Biceps at the wall", .arms, ["arms", "chest"], 30, sides: 2),

        StretchItem("childs-pose", "Child's pose", .back, ["back"], 40, sides: 1),
        StretchItem("cat-cow", "Cat and cow", .back, ["back", "core"], 40, sides: 1),
        StretchItem("spine-twist", "Seated spinal twist", .back, ["back", "core"], 30, sides: 2),
        StretchItem("cobra", "Cobra", .back, ["core", "back"], 30, sides: 1),
        StretchItem("knee-chest", "Knee to chest", .back, ["back", "legs"], 30, sides: 2),
        StretchItem("upper-back-hug", "Upper back hug", .back, ["back", "shoulders"], 30, sides: 1),

        StretchItem("figure-four", "Figure four", .hips, ["legs"], 40, sides: 2),
        StretchItem("ninety-ninety", "90/90 hip", .hips, ["legs"], 40, sides: 2),
        StretchItem("hip-flexor", "Hip flexor lunge", .hips, ["legs", "core"], 40, sides: 2),
        StretchItem("butterfly", "Butterfly", .hips, ["legs"], 40, sides: 1),
        StretchItem("wide-adductor", "Wide-leg adductor", .hips, ["legs"], 40, sides: 1),
        StretchItem("glute-seated", "Seated glute", .hips, ["legs"], 30, sides: 2),

        StretchItem("quad-standing", "Standing quad", .legs, ["legs"], 30, sides: 2),
        StretchItem("hamstring-seated", "Seated hamstring", .legs, ["legs"], 40, sides: 2),
        StretchItem("forward-fold", "Standing forward fold", .legs, ["legs", "back"], 30, sides: 1),
        StretchItem("calf-wall", "Calf at the wall", .legs, ["legs"], 30, sides: 2),
        StretchItem("calf-bent", "Bent-knee calf", .legs, ["legs"], 30, sides: 2),
        StretchItem("side-leg-cross", "Cross-leg side stretch", .legs, ["legs", "core"], 30, sides: 2),
        StretchItem("side-bend", "Standing side bend", .legs, ["core", "back"], 20, sides: 2),

        StretchItem("legs-up", "Legs up the wall", .finish, [], 60, sides: 1),
        StretchItem("deep-breathing", "Deep breathing", .finish, [], 60, sides: 1),
    ]

    public static let moves: [StretchItem] = [
        StretchItem("dyn-arm-circles", "Arm circles", .warm, ["shoulders", "chest", "arms"], 30, sides: 1),
        StretchItem("dyn-leg-swing-front", "Leg swings forward and back", .warm, ["legs"], 30, sides: 2),
        StretchItem("dyn-leg-swing-side", "Leg swings side to side", .warm, ["legs"], 30, sides: 2),
        StretchItem("dyn-hip-circles", "Hip circles", .warm, ["legs", "core"], 30, sides: 1),
        StretchItem("dyn-lunge-twist", "Lunge with a twist", .warm, ["legs", "core"], 30, sides: 1),
        StretchItem("dyn-inchworm", "Inchworm", .warm, ["legs", "core", "shoulders", "chest"], 30, sides: 1),
        StretchItem("dyn-squat", "Body-weight squat", .warm, ["legs"], 30, sides: 1),
        StretchItem("dyn-glute-bridge", "Glute bridge", .warm, ["legs", "core"], 30, sides: 1),
        StretchItem("dyn-torso-turns", "Torso turns", .warm, ["core", "back"], 30, sides: 1),
        StretchItem("dyn-worlds-greatest", "World's greatest stretch", .warm, ["legs", "back"], 30, sides: 2),
    ]

    public static var all: [StretchItem] { stretches + moves }

    public static func item(_ id: String) -> StretchItem? { all.first { $0.id == id } }
}
