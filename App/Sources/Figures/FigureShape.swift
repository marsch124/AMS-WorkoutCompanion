import SwiftUI
import WorkoutCore

/// Draws parsed figure lines (the 64 x 64 grid) as smooth curves into any square rectangle.
/// Lines only, no fill; the head is an open circle.
struct FigureLines: Shape {
    var strokes: [FigureStroke]
    var head: FigureHead?
    var mirrored: Bool

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        let ox = rect.midX - 32 * s, oy = rect.midY - 32 * s
        func map(_ p: FigurePoint, fixed: Bool) -> CGPoint {
            let x = (mirrored && !fixed) ? 64 - p.x : p.x
            return CGPoint(x: ox + x * s, y: oy + p.y * s)
        }
        var path = Path()
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            path.move(to: map(first, fixed: stroke.fixed))
            for seg in FigureParser.curve(stroke) {
                path.addCurve(to: map(seg.end, fixed: stroke.fixed),
                              control1: map(seg.c1, fixed: stroke.fixed),
                              control2: map(seg.c2, fixed: stroke.fixed))
            }
        }
        if let h = head {
            let c = map(FigurePoint(h.x, h.y), fixed: false)
            path.addEllipse(in: CGRect(x: c.x - h.r * s, y: c.y - h.r * s, width: 2 * h.r * s, height: 2 * h.r * s))
        }
        return path
    }
}
