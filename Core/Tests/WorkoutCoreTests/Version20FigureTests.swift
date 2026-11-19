import XCTest
@testable import WorkoutCore

final class Version20FigureTests: XCTestCase {
    func testEveryLibraryItemHasAFigureThatParsesInsideTheGrid() {
        for item in StretchLibrary.all {
            guard let text = FigureData.pose(item.id) else { return XCTFail("no figure for \(item.id)") }
            guard let fig = FigureParser.parse(text) else { return XCTFail("does not parse: \(item.id)") }
            for p in fig.bodyPoints + fig.props.flatMap({ $0.points }) {
                XCTAssertTrue((0...64).contains(p.x) && (0...64).contains(p.y), "\(item.id) point outside: \(p)")
            }
            for f in fig.frames {
                guard let h = f.head else { return XCTFail("no head: \(item.id)") }
                XCTAssertTrue(h.x - h.r >= 0 && h.x + h.r <= 64 && h.y - h.r >= 0 && h.y + h.r <= 64, "head outside: \(item.id)")
            }
        }
        XCTAssertEqual(FigureData.poses.count, StretchLibrary.all.count)
    }

    func testWarmUpMovesHaveTwoMatchingFramesAndStretchesOne() {
        for m in StretchLibrary.moves {
            let fig = FigureParser.parse(FigureData.pose(m.id) ?? "")
            XCTAssertEqual(fig?.frames.count, 2, m.id)
            XCTAssertEqual(fig?.framesMatch, true, m.id)
        }
        for s in StretchLibrary.stretches {
            XCTAssertEqual(FigureParser.parse(FigureData.pose(s.id) ?? "")?.frames.count, 1, s.id)
        }
    }

    func testBlendAndLoop() {
        let fig = FigureParser.parse("o10,10,4;p0,0 10,10 | s0,60 60,60 // o20,10,4;p10,0 20,20")!
        XCTAssertEqual(fig.blended(0.5).strokes[0].points[1], FigurePoint(15, 15))
        XCTAssertEqual(ParsedFigure.loopPhase(seconds: 0), 0, accuracy: 0.001)
        XCTAssertEqual(ParsedFigure.loopPhase(seconds: 0.8, period: 1.6), 1, accuracy: 0.001)
        XCTAssertNil(FigureParser.parse("x1,2"))
    }
}
