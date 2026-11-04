import AMSIcons
import SwiftUI

/// A label made of a hand-drawn control mark from the AMS-Icons hub and words, for buttons.
struct MarkLabel: View {
    let title: String
    let mark: ControlMark
    var size: CGFloat = 20
    var colour: Color

    var body: some View {
        HStack(spacing: 8) {
            ControlMarkView(mark, size: size, colour: colour)
            Text(title)
        }
    }
}

/// Small hand-drawn marks the AMS-Icons hub does not have yet (since 1.11), in its style:
/// 24-point grid, one 1.9 stroke with round ends, no fill.
enum AppMark: String {
    /// A magnifying glass, for search fields.
    case search = "M5 10.5a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0 -11 0 M14.6 14.6l4.9 4.9"
    /// Two links, for a superset pair.
    case pair = "M10 14l4-4 M8.6 11.6l-2 2a3 3 0 0 0 4.2 4.2l2-2 M15.4 12.4l2-2a3 3 0 0 0 -4.2 -4.2l-2 2"
    /// A bookmark, for keeping a plan as a template (since 1.13).
    case template = "M7 4.5h10v15l-5 -3.6l-5 3.6Z M10 8.5h4"
    /// A small flame, for a warm-up set.
    case warmup = "M12 4c2.4 3.2 5 5.2 5 9a5 5 0 0 1 -10 0c0 -2.2 1.2 -3.5 2.3 -4.5c.3 1.6 1 2.4 1.9 2.7C11.5 8.6 11.4 6.6 12 4Z"
}

struct AppMarkView: View {
    let mark: AppMark
    var size: CGFloat = 18
    var colour: Color

    init(_ mark: AppMark, size: CGFloat = 18, colour: Color) {
        self.mark = mark
        self.size = size
        self.colour = colour
    }

    var body: some View {
        GridShape(d: mark.rawValue)
            .stroke(colour, style: StrokeStyle(lineWidth: size * 1.9 / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
