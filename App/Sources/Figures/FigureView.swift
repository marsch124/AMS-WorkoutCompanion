import SwiftUI
import WorkoutCore

/// PLACEHOLDER (2.0 groundwork) — the figures lane replaces this file.
/// The drawn picture of a stretch or warm-up move, by library id ("quad-standing", "dyn-squat").
/// `mirrored` draws the second side; `animated` loops a warm-up move's two frames.
struct FigureView: View {
    let id: String
    var size: CGFloat = 36
    var mirrored = false
    var animated = false
    var tint: Color = Theme.accent

    var body: some View {
        Circle().stroke(tint, lineWidth: max(1.5, size * 0.045))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    /// True when the library id has a drawing (own stretches have none).
    static func has(_ id: String) -> Bool { false }
}
