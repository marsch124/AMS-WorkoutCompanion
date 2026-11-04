import ActivityKit
import WorkoutCore

/// A rest on the lock screen and in the Dynamic Island (since 1.15). Shared by the app,
/// which starts and ends it, and the RestWidget extension, which draws it.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var card: RestCard
    }
}
