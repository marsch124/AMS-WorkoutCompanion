import AMSIcons
import SwiftUI

/// The control marks (Done, Skip, Close…) — the workout icons themselves come from the
/// AMS-Icons hub. These are drawn the hub's way (GridShape: one 1.9 stroke, round ends,
/// 24-point grid, no fill) because the hub has no control marks yet; they belong in the
/// hub once it has a place for them.
enum Marks {
    static let checklist = "M10 6.5h10 M10 12h10 M10 17.5h10 M3.8 6.5l1.4 1.4 2.4-2.6 M3.8 12l1.4 1.4 2.4-2.6 M3.8 17.5l1.4 1.4 2.4-2.6"
    static let plus = "M12 5v14 M5 12h14"
    static let pencil = "M4.5 19.5l1-4.4L15.6 5a2.1 2.1 0 0 1 3 3L8.5 18.4Z M13.6 7l3 3"
    static let play = "M8 5.5v13l10-6.5Z"
    static let pause = "M9 6v12 M15 6v12"
    static let skip = "M5.5 6.5l8 5.5-8 5.5Z M18 6.5v11"
    static let check = "M5 12.5l4.5 4.5L19 7.5"
    static let close = "M6.5 6.5l11 11 M17.5 6.5l-11 11"
    static let circle = "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0"
    static let ticked = "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M8.2 12.3l2.6 2.6 5-5.2"
    static let photo = "M3.5 6h17v12h-17Z M3.5 15.5l4.8-4.3 4 3.6 2.9-2.4 5.3 4.4 M15.2 9.3a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0"
    static let expand = "M14 4.5h5.5V10 M19.5 4.5 14 10 M10 19.5H4.5V14 M4.5 19.5 10 14"
    static let chevron = "M9.5 5.5 16 12l-6.5 6.5"
    static let more = "M6 12h.01 M12 12h.01 M18 12h.01"
    static let gear = "M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M12 3.5v2.6 M12 17.9v2.6 M3.5 12h2.6 M17.9 12h2.6 M6 6l1.8 1.8 M16.2 16.2 18 18 M6 18l1.8-1.8 M16.2 7.8 18 6"
    static let plusAdd = "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M12 8.5v7 M8.5 12h7"
}

/// A hand-drawn mark at any size: the 1.9 stroke scales with it, ends and joins round.
struct Mark: View {
    let d: String
    var size: CGFloat = 22
    var colour: Color = Theme.ink

    init(_ d: String, size: CGFloat = 22, colour: Color = Theme.ink) {
        self.d = d
        self.size = size
        self.colour = colour
    }

    var body: some View {
        GridShape(d: d)
            .stroke(colour, style: StrokeStyle(lineWidth: 1.9 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A label made of a hand-drawn mark and words, for buttons.
struct MarkLabel: View {
    let title: String
    let d: String
    var size: CGFloat = 20
    var colour: Color

    var body: some View {
        HStack(spacing: 8) {
            Mark(d, size: size, colour: colour)
            Text(title)
        }
    }
}
