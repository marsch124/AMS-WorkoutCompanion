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
