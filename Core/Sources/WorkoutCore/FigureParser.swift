import Foundation

/// One point of a figure on the 64 x 64 grid (y down, floor at y = 60).
public struct FigurePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// A line through points: drawn as one smooth curve (`smooth`) or straight.
public struct FigureStroke: Equatable, Sendable {
    public var points: [FigurePoint]
    public var smooth: Bool
    /// Props marked `!` keep their place when the figure is mirrored.
    public var fixed: Bool
    public init(points: [FigurePoint], smooth: Bool, fixed: Bool = false) {
        self.points = points; self.smooth = smooth; self.fixed = fixed
    }
}

public struct FigureHead: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var r: Double
    public init(x: Double, y: Double, r: Double) { self.x = x; self.y = y; self.r = r }
}

/// The moving part of a figure: the head and the body lines.
public struct FigureFrame: Equatable, Sendable {
    public var head: FigureHead?
    public var strokes: [FigureStroke]
}

/// A cubic piece of a smooth line.
public struct FigureCurveSegment: Equatable, Sendable {
    public var c1: FigurePoint
    public var c2: FigurePoint
    public var end: FigurePoint
}

/// A parsed figure: one or two frames plus props (floor, wall, bar, door frame, bench).
public struct ParsedFigure: Equatable, Sendable {
    public var frames: [FigureFrame]
    public var props: [FigureStroke]

    /// Two frames = a warm-up move that can be animated.
    public var isMove: Bool { frames.count > 1 }

    /// Every point of the frames (not the props, not the head circle's rim).
    public var bodyPoints: [FigurePoint] { frames.flatMap { $0.strokes.flatMap { $0.points } } }

    /// True when all frames have the same head and the same lines with the same point counts.
    public var framesMatch: Bool {
        guard let first = frames.first else { return false }
        return frames.dropFirst().allSatisfy { f in
            (f.head == nil) == (first.head == nil)
                && f.strokes.count == first.strokes.count
                && zip(f.strokes, first.strokes).allSatisfy { $0.points.count == $1.points.count && $0.smooth == $1.smooth }
        }
    }

    /// Blend of the two frames, `t` 0 = first, 1 = second (frames must match, else the first).
    public func blended(_ t: Double) -> FigureFrame {
        guard frames.count > 1, framesMatch else { return frames[0] }
        let a = frames[0], b = frames[1]
        let k = min(max(t, 0), 1)
        func mix(_ p: Double, _ q: Double) -> Double { p + (q - p) * k }
        var out = a
        if let ha = a.head, let hb = b.head {
            out.head = FigureHead(x: mix(ha.x, hb.x), y: mix(ha.y, hb.y), r: mix(ha.r, hb.r))
        }
        for i in out.strokes.indices {
            for j in out.strokes[i].points.indices {
                let p = a.strokes[i].points[j], q = b.strokes[i].points[j]
                out.strokes[i].points[j] = FigurePoint(mix(p.x, q.x), mix(p.y, q.y))
            }
        }
        return out
    }

    /// The loop of an animated move: 0 → 1 → 0 with ease-in-out, `period` seconds for the whole there-and-back.
    public static func loopPhase(seconds: Double, period: Double = 1.6) -> Double {
        guard period > 0 else { return 0 }
        let x = seconds.truncatingRemainder(dividingBy: period) / period
        return (1 - cos(2 * Double.pi * x)) / 2
    }
}

public enum FigureParser {
    /// Text format (see FigureData): frames separated by ` // `; in each frame the body parts, then
    /// after ` | ` the props. Returns nil when anything is malformed.
    public static func parse(_ text: String) -> ParsedFigure? {
        let frameTexts = text.components(separatedBy: " // ")
        var frames: [FigureFrame] = []
        var props: [FigureStroke] = []
        for (n, frameText) in frameTexts.enumerated() {
            let halves = frameText.components(separatedBy: " | ")
            guard halves.count <= 2 else { return nil }
            var frame = FigureFrame(head: nil, strokes: [])
            for raw in halves[0].split(separator: ";") {
                let seg = raw.trimmingCharacters(in: .whitespaces)
                guard let kind = seg.first else { continue }
                let body = String(seg.dropFirst())
                switch kind {
                case "o":
                    let v = body.split(separator: ",").compactMap { Double($0) }
                    guard v.count == 3, frame.head == nil else { return nil }
                    frame.head = FigureHead(x: v[0], y: v[1], r: v[2])
                case "p", "s":
                    guard let pts = points(body), pts.count >= 2 else { return nil }
                    frame.strokes.append(FigureStroke(points: pts, smooth: kind == "p"))
                default: return nil
                }
            }
            guard !frame.strokes.isEmpty else { return nil }
            frames.append(frame)
            if n == 0, halves.count == 2 {
                for raw in halves[1].split(separator: ";") {
                    var seg = raw.trimmingCharacters(in: .whitespaces)
                    guard !seg.isEmpty else { continue }
                    var fixed = false
                    if seg.hasPrefix("!") { fixed = true; seg.removeFirst() }
                    guard let kind = seg.first, kind == "p" || kind == "s",
                          let pts = points(String(seg.dropFirst())), pts.count >= 2 else { return nil }
                    props.append(FigureStroke(points: pts, smooth: kind == "p", fixed: fixed))
                }
            }
        }
        guard !frames.isEmpty, frames.count <= 2 else { return nil }
        return ParsedFigure(frames: frames, props: props)
    }

    private static func points(_ body: String) -> [FigurePoint]? {
        var out: [FigurePoint] = []
        for pair in body.split(separator: " ") {
            let v = pair.split(separator: ",").compactMap { Double($0) }
            guard v.count == 2 else { return nil }
            out.append(FigurePoint(v[0], v[1]))
        }
        return out
    }

    /// Smooth line through the points (Catmull-Rom turned into cubic pieces); a straight line when `smooth` is false
    /// or there are only two points.
    public static func curve(_ stroke: FigureStroke) -> [FigureCurveSegment] {
        let p = stroke.points
        guard p.count >= 2 else { return [] }
        var out: [FigureCurveSegment] = []
        for i in 0..<(p.count - 1) {
            let p1 = p[i], p2 = p[i + 1]
            if !stroke.smooth || p.count == 2 {
                out.append(FigureCurveSegment(c1: p1, c2: p2, end: p2)); continue
            }
            let p0 = i > 0 ? p[i - 1] : p1
            let p3 = i + 2 < p.count ? p[i + 2] : p2
            out.append(FigureCurveSegment(
                c1: FigurePoint(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6),
                c2: FigurePoint(p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6),
                end: p2))
        }
        return out
    }
}
