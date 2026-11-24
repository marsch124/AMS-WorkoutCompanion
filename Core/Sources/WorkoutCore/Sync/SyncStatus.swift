import Foundation

/// How this device stands with the app's iCloud folder (since 3.0) — the dot at the foot of the side
/// list and the line on Settings → iCloud.
public enum SyncStatus: Equatable, Sendable {
    /// iCloud is not signed in, or iCloud Drive is off for this app, on this device.
    case off
    /// Looking for iCloud, fetching or sending.
    case working
    /// This device and iCloud hold the same; when they last met.
    case current(Date)
    /// Something stands in the way; the words say what.
    case problem(String)

    public enum Dot: String, Sendable { case green, orange, grey, red }

    /// Green = the same on all devices, orange = on its way, grey = iCloud off, red = a problem.
    public var dot: Dot {
        switch self {
        case .off: return .grey
        case .working: return .orange
        case .current: return .green
        case .problem: return .red
        }
    }

    /// A few plain words beside the dot.
    public var words: String {
        switch self {
        case .off: return "iCloud is off"
        case .working: return "Syncing…"
        case .current: return "Same on all devices"
        case .problem(let why): return why
        }
    }
}
