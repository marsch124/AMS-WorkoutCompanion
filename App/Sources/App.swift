import SwiftUI
import WorkoutCore

@main
struct AMSWorkoutCompanionApp: App {
    @State private var library = Library.launch()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .tint(Theme.accent)
                // A rest left on the lock screen from before the app was closed (since 1.15).
                .task { RestLive.end() }
        }
        // Leaving the app: the day's automatic backup, if one is due (since 1.7).
        .onChange(of: phase) { _, now in
            if now == .background { library.autoBackupIfDue() }
        }
    }
}
