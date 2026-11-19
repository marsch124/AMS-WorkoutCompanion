import SwiftUI
import WorkoutCore

/// PLACEHOLDER (2.0 groundwork) — the stretch lane replaces this file.
/// Stretching inside a gym visit: opens the stretch chooser (his ticks and order, today's suggestions),
/// runs the timer, and hands back what was done. `onFinished(nil)` = closed without stretching.
struct StretchSessionEntry: View {
    let visitID: UUID?
    let onFinished: (VisitPart?) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Stretching")
            Button("Done") { onFinished(VisitPart(kind: .stretch, start: Date(), end: Date())) }
                .accessibilityIdentifier("stretch-entry-done")
        }
    }
}
