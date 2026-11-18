import ActivityKit
import WorkoutCore

/// The gym session on the lock screen and in the Dynamic Island (since 1.23). Shared by the app,
/// which starts, updates and ends it, and the RestWidget extension, which draws it.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var card: SessionCard
    }
}
