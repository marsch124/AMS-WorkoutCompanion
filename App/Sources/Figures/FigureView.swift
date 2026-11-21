import SwiftUI
import WorkoutCore

/// The drawn picture of a stretch or warm-up move, by library id ("quad-standing", "dyn-squat"),
/// in the style "one flowing line" (2.0). `mirrored` draws the second side; `animated` loops a
/// warm-up move's two frames. The line is ink by default; props (floor, wall, bar) are thinner and fainter.
struct FigureView: View {
    let id: String
    var size: CGFloat
    var mirrored: Bool
    var animated: Bool
    var tint: Color
    private let figure: ParsedFigure?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: String, size: CGFloat = 36, mirrored: Bool = false, animated: Bool = false, tint: Color = Theme.ink) {
        self.id = id; self.size = size; self.mirrored = mirrored; self.animated = animated; self.tint = tint
        self.figure = FigureData.pose(id).flatMap(FigureParser.parse)
    }

    var body: some View {
        Group {
            if let figure {
                if animated && figure.isMove && !reduceMotion {
                    TimelineView(.animation) { context in
                        let t = FigureParsed.phase(context.date.timeIntervalSinceReferenceDate)
                        picture(figure, figure.blended(t))
                    }
                } else {
                    picture(figure, figure.frames[0])
                }
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func picture(_ figure: ParsedFigure, _ frame: FigureFrame) -> some View {
        let w = max(1.2, size * 0.04)
        return ZStack {
            FigureLines(strokes: figure.props, head: nil, mirrored: mirrored)
                .stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: w * 0.55, lineCap: .round, lineJoin: .round))
            FigureLines(strokes: frame.strokes, head: frame.head, mirrored: mirrored)
                .stroke(tint, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }

    /// True when the library id has a drawing (own stretches have none).
    static func has(_ id: String) -> Bool { FigureData.pose(id) != nil }
}

private enum FigureParsed {
    static func phase(_ seconds: Double) -> Double { ParsedFigure.loopPhase(seconds: seconds, period: 1.6) }
}
