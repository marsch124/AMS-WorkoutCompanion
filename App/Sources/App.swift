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
        }
        // Leaving the app: the day's automatic backup, if one is due (since 1.7).
        .onChange(of: phase) { _, now in
            if now == .background { library.autoBackupIfDue() }
        }
    }
}
