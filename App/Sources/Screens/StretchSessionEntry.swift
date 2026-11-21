import SwiftUI
import WorkoutCore

/// Stretching inside a gym visit (since 2.0): the chooser (his ticks and order, today's suggestions),
/// then the timer, then it hands back what was done. `onFinished(nil)` = closed without stretching.
/// Nothing is recorded as a separate session here; the visit keeps the VisitPart.
struct StretchSessionEntry: View {
    let visitID: UUID?
    let onFinished: (VisitPart?) -> Void

    @State private var picks: [StretchPick]?
    @State private var outcome: StretchOutcome?
    @State private var done = false

    var body: some View {
        Group {
            if let picks {
                StretchTimerScreen(picks: picks, onFinish: { outcome = $0 }, onClose: finish)
            } else {
                StretchChooser(visitID: visitID, onStart: { picks = $0 }, onCancel: finish)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func finish() {
        guard !done else { return }
        done = true
        guard let o = outcome else { onFinished(nil); return }
        var part = VisitPart(kind: .stretch, start: o.start, end: o.end)
        part.names = o.held
        part.held = o.held.count
        part.skipped = o.skipped
        onFinished(part)
    }
}
