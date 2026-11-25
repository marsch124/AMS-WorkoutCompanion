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
                // 3.1: amsworkouts://open brings the app to the front; any other address is ignored.
                .onOpenURL { TrainingLink.handle($0) }
                // A rest left on the lock screen from before the app was closed (since 1.15).
                .task {
                    RestLive.end()
                    // The gym session on the lock screen and the gym reminder, as things stand now (since 1.23).
                    SessionLive.sync(library.gym)
                    GymNudge.sync(library.gym)
                    Cues.shared.reload()
                    // 3.0: meet iCloud.
                    library.cloud?.start()
                }
        }
        // Leaving the app: the day's automatic backup, if one is due (since 1.7).
        .onChange(of: phase) { _, now in
            if now == .background {
                library.autoBackupIfDue()
                library.writeBoardFile()
            }
            // Back in front: what the other devices did meanwhile comes in (3.0).
            if now == .active { library.cloud?.start() }
        }
    }
}
