import SwiftUI
import WorkoutCore

@main
struct AMSWorkoutCompanionApp: App {
    @State private var library = Library.launch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .tint(Theme.accent)
        }
    }
}
