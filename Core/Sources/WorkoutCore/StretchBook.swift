import Foundation

/// A stretch he made himself (since 2.0). Id "my-<uuid>".
public struct CustomStretch: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var seconds: Int
    /// 1 or 2.
    public var sides: Int
    public var note: String
    /// A StretchArea raw value; nil = no area.
    public var area: String?
    /// His own photo in the Photos folder (kept by photosInUse).
    public var photo: String?

    public init(id: String = "my-" + UUID().uuidString, name: String, seconds: Int = 30, sides: Int = 1,
                note: String = "", area: String? = nil, photo: String? = nil) {
        self.id = id; self.name = name; self.seconds = seconds; self.sides = sides
        self.note = note; self.area = area; self.photo = photo
    }
}

/// What he chose for the warm-up last time, so the next one opens the same way (since 2.0).
public struct WarmPrefs: Codable, Hashable, Sendable {
    public var kind: VisitPart.Kind?
    public var minutes: Int?
    public var machineID: UUID?
    /// Ticked warm-up moves, in his order (library ids).
    public var moves: [String]?
    public init(kind: VisitPart.Kind? = nil, minutes: Int? = nil, machineID: UUID? = nil, moves: [String]? = nil) {
        self.kind = kind; self.minutes = minutes; self.machineID = machineID; self.moves = moves
    }
}

/// His stretching and warm-up memory (since 2.0), kept in gym.json under "book":
/// the stretches he ticked in HIS order, changed hold times, favourites and his own stretches.
public struct StretchBook: Codable, Hashable, Sendable {
    /// Ticked stretch ids (library or "my-…"), in his order — "My stretches".
    public var ticked: [String] = []
    /// Seconds per side, only for stretches whose time he changed.
    public var holds: [String: Int] = [:]
    public var favourites: [String] = []
    public var custom: [CustomStretch] = []
    public var warm: WarmPrefs?
    /// The old stretch list (GymLog.stretchID) already taken over, so it happens once.
    public var migratedFrom: UUID?

    public init() {}

    enum CodingKeys: String, CodingKey { case ticked, holds, favourites, custom, warm, migratedFrom }

    /// Missing or odd parts read as empty, never as a broken file.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ticked = (try? c.decodeIfPresent([String].self, forKey: .ticked)) ?? []
        holds = (try? c.decodeIfPresent([String: Int].self, forKey: .holds)) ?? [:]
        favourites = (try? c.decodeIfPresent([String].self, forKey: .favourites)) ?? []
        custom = (try? c.decodeIfPresent([CustomStretch].self, forKey: .custom)) ?? []
        warm = (try? c.decodeIfPresent(WarmPrefs.self, forKey: .warm)) ?? nil
        migratedFrom = (try? c.decodeIfPresent(UUID.self, forKey: .migratedFrom)) ?? nil
    }
}
