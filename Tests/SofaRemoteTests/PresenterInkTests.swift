import Foundation
import Testing
@testable import SofaRemote

@Suite struct PresenterInkTests {
    @Test func rejectsInvalidAndOutOfOrderPoints() {
        var ink = PresenterInk()
        let result1 = ink.move(x: 0.5, y: 0.5)
        #expect(!result1)
        let result2 = ink.begin(mode: .pen, x: .nan, y: 0.1)
        #expect(!result2)
        let result3 = ink.begin(mode: .laser, x: 1.01, y: 0.1)
        #expect(!result3)
        let result4 = ink.begin(mode: .laser, x: 0, y: 1)
        #expect(result4)
        let result5 = ink.begin(mode: .pen, x: 0.5, y: 0.5)
        #expect(!result5)
        let result6 = ink.move(x: -.infinity, y: 0.5)
        #expect(!result6)
        ink.end()
        #expect(ink.cursor == nil && !ink.active)
    }
    @Test func inkCanBeUndoneAndCleared() {
        var ink = PresenterInk()
        let result7 = ink.begin(mode: .pen, x: 0.1, y: 0.2)
        #expect(result7)
        let result8 = ink.move(x: 0.3, y: 0.4)
        #expect(result8)
        ink.end()
        let result9 = ink.begin(mode: .pen, x: 0.6, y: 0.7)
        #expect(result9)
        ink.end()
        #expect(ink.strokes.count == 2)
        ink.undo()
        #expect(ink.strokes.count == 1 && ink.strokes[0].points.count == 2)
        ink.clear()
        #expect(ink.strokes.isEmpty && ink.cursor == nil && !ink.active)
    }
    @Test func boundsMemoryPerPresenterSession() {
        var ink = PresenterInk()
        for _ in 0..<PresenterInk.maxStrokes {
            let result10 = ink.begin(mode: .pen, x: 0.5, y: 0.5)
            #expect(result10)
            ink.end()
        }
        let result11 = ink.begin(mode: .pen, x: 0.5, y: 0.5)
        #expect(!result11)
        ink.undo()
        let result12 = ink.begin(mode: .pen, x: 0.5, y: 0.5)
        #expect(result12)
        for _ in 0..<(PresenterInk.maxPoints - PresenterInk.maxStrokes) {
            let result13 = ink.move(x: 0.5, y: 0.5)
            #expect(result13)
        }
        let result14 = ink.move(x: 0.5, y: 0.5)
        #expect(!result14)
        ink.clear()
        let result15 = ink.begin(mode: .pen, x: 0.5, y: 0.5)
        #expect(result15)
    }
    @Test func colorsReticleAndSinglePointAreKeptPerStroke() {
        var ink = PresenterInk()
        let began = ink.begin(mode: .pen, color: .green, x: 0.25, y: 0.75)
        #expect(began)
        #expect(ink.cursor == CGPoint(x: 0.25, y: 0.75))
        #expect(ink.cursorColor == .green)
        #expect(ink.strokes.count == 1 && ink.strokes[0].points.count == 1)
        #expect(ink.strokes[0].color == .green && ink.strokes[0].mode == .pen)
        ink.end()
        #expect(ink.cursor == nil && ink.strokes.count == 1)
        let laser = ink.begin(mode: .laser, color: .blue, x: 0.5, y: 0.5)
        #expect(laser && ink.cursorColor == .blue && ink.strokes.count == 1)
    }
    @Test func onlyFinishedHighlightExpiresWithoutDamagingOtherMarks() throws {
        var ink = PresenterInk()
        let pen = ink.begin(mode: .pen, color: .blue, x: 0.1, y: 0.1)
        #expect(pen)
        ink.end()
        let highlight = ink.begin(mode: .highlight, color: .yellow, x: 0.2, y: 0.2)
        #expect(highlight)
        let highlightID = try #require(ink.strokes.last?.id)
        let activeExpiry = ink.expireHighlight(id: highlightID)
        #expect(!activeExpiry && ink.strokes.count == 2)
        let scheduled = ink.end()
        #expect(scheduled == highlightID)
        let next = ink.begin(mode: .pen, color: .green, x: 0.3, y: 0.3)
        #expect(next)
        let expired = ink.expireHighlight(id: highlightID)
        #expect(expired && ink.strokes.count == 2 && ink.active)
        #expect(ink.strokes.map(\.color) == [.blue, .green])
        let stale = ink.expireHighlight(id: highlightID)
        #expect(!stale)
        ink.clear()
        let cleared = ink.expireHighlight(id: highlightID)
        #expect(!cleared && ink.strokes.isEmpty)
    }
    @Test func undoAndExpirationReleasePointAndStrokeCapacity() throws {
        var ink = PresenterInk()
        for _ in 0..<PresenterInk.maxStrokes {
            let began = ink.begin(mode: .highlight, x: 0.5, y: 0.5)
            #expect(began)
            ink.end()
        }
        let full = ink.begin(mode: .pen, x: 0.5, y: 0.5)
        #expect(!full)
        let oldest = try #require(ink.strokes.first?.id)
        let expired = ink.expireHighlight(id: oldest)
        #expect(expired)
        let again = ink.begin(mode: .pen, color: .red, x: 0.5, y: 0.5)
        #expect(again)
        let removed = ink.undo()
        #expect(removed != nil && ink.strokes.count == PresenterInk.maxStrokes - 1)
    }

    @Test func highlightStillExpiresWhileLaserIsHeld() throws {
        var ink = PresenterInk()
        let began = ink.begin(mode: .highlight, color: .yellow, x: 0.3, y: 0.4)
        #expect(began)
        let finished = ink.end()
        let id = try #require(finished)
        let laser = ink.begin(mode: .laser, color: .red, x: 0.1, y: 0.1)
        #expect(laser)
        let expired = ink.expireHighlight(id: id)
        #expect(expired && ink.strokes.isEmpty && ink.active && ink.cursor != nil)
    }

    @Test func smoothingIsOptInAndPreservesRawEndpointsAndCursor() throws {
        var smoothed = PresenterInk()
        let start = CGPoint(x: 0.1, y: 0.5), end = CGPoint(x: 0.9, y: 0.5)
        let began = smoothed.begin(mode: .pen, smoothing: true, x: start.x, y: start.y)
        #expect(began)
        let raw = (1...19).map { i in CGPoint(x: 0.1 + Double(i) * 0.04, y: 0.5 + (i.isMultiple(of: 2) ? 0.01 : -0.01)) } + [end]
        for point in raw { let moved = smoothed.move(x: point.x, y: point.y); #expect(moved) }
        #expect(smoothed.cursor == end)
        smoothed.end()
        let points = try #require(smoothed.strokes.first?.points)
        #expect(points.first == start && points.last == end)
        let filteredError = points.dropFirst().dropLast().reduce(0.0) { $0 + abs($1.y - 0.5) }
        let rawError = raw.dropLast().reduce(0.0) { $0 + abs($1.y - 0.5) }
        #expect(filteredError < rawError * 0.7)
        var rawInk = PresenterInk()
        let rawBegan = rawInk.begin(mode: .pen, x: start.x, y: start.y)
        #expect(rawBegan)
        for point in raw { let moved = rawInk.move(x: point.x, y: point.y); #expect(moved) }
        rawInk.end()
        #expect(rawInk.strokes[0].points == [start] + raw)
    }
    @Test func smoothingAtCapacityRetainsLastPointWithoutBreakingBound() throws {
        var ink = PresenterInk()
        let began = ink.begin(mode: .pen, smoothing: true, x: 0.1, y: 0.1)
        #expect(began)
        for i in 1..<PresenterInk.maxPoints {
            let moved = ink.move(x: i.isMultiple(of: 2) ? 0.9 : 0.1, y: 0.5)
            #expect(moved)
        }
        let last = try #require(ink.cursor)
        ink.end()
        #expect(ink.strokes[0].points.count == PresenterInk.maxPoints)
        #expect(ink.strokes[0].points.last == last)
    }
    @Test func nearStraightLinesSnapOnlyWhenEnabled() throws {
        let points = (0...20).map { i in CGPoint(x: 0.1 + Double(i) * 0.04, y: 0.4 + 0.001 * sin(Double(i))) }
        var corrected = PresenterInk()
        let began = corrected.begin(mode: .pen, shapeCorrection: true, aspectRatio: 16.0 / 9.0, x: points[0].x, y: points[0].y)
        #expect(began)
        for point in points.dropFirst() { let moved = corrected.move(x: point.x, y: point.y); #expect(moved) }
        corrected.end()
        #expect(corrected.strokes[0].points == [points.first!, points.last!])
        var plain = PresenterInk()
        let plainBegan = plain.begin(mode: .pen, x: points[0].x, y: points[0].y)
        #expect(plainBegan)
        for point in points.dropFirst() { let moved = plain.move(x: point.x, y: point.y); #expect(moved) }
        plain.end()
        #expect(plain.strokes[0].points == points)
    }
    @Test func closedCirclesRespectLandscapeAndPortraitDisplayAspect() throws {
        for aspect: CGFloat in [16.0 / 9.0, 9.0 / 16.0] {
            let points = (0...32).map { i -> CGPoint in
                let angle = 2 * CGFloat.pi * CGFloat(i) / 32
                return CGPoint(x: 0.5 + 0.22 * cos(angle) / aspect, y: 0.5 + 0.22 * sin(angle))
            }
            var ink = PresenterInk()
            let began = ink.begin(mode: .highlight, color: .yellow, smoothing: true, shapeCorrection: true, aspectRatio: aspect, x: points[0].x, y: points[0].y)
            #expect(began)
            for point in points.dropFirst() { let moved = ink.move(x: point.x, y: point.y); #expect(moved) }
            let highlightID = ink.end()
            let mark = try #require(ink.strokes.first)
            #expect(mark.mode == .highlight && mark.points.count == 65)
            let xs = mark.points.map { $0.x * aspect }, ys = mark.points.map(\.y)
            let width = try #require(xs.max()) - #require(xs.min())
            let height = try #require(ys.max()) - #require(ys.min())
            #expect(abs(width - height) < 0.001)
            #expect(mark.points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
            let expired = ink.expireHighlight(id: try #require(highlightID))
            #expect(expired && ink.strokes.isEmpty)
        }
    }
    @Test func ambiguousCurvesEllipsesAndOpenArcsStayFreehand() {
        let wave = (0...24).map { i in CGPoint(x: 0.1 + CGFloat(i) * 0.8 / 24, y: 0.5 + 0.1 * sin(CGFloat(i) * 2 * .pi / 24)) }
        #expect(PresenterShapeCorrection.correct(wave, aspectRatio: 1) == nil)
        let ellipse = (0...32).map { i -> CGPoint in
            let a = 2 * CGFloat.pi * CGFloat(i) / 32
            return CGPoint(x: 0.5 + 0.3 * cos(a), y: 0.5 + 0.12 * sin(a))
        }
        #expect(PresenterShapeCorrection.correct(ellipse, aspectRatio: 1) == nil)
        let arc = (0...24).map { i -> CGPoint in
            let a = 1.5 * CGFloat.pi * CGFloat(i) / 24
            return CGPoint(x: 0.5 + 0.2 * cos(a), y: 0.5 + 0.2 * sin(a))
        }
        #expect(PresenterShapeCorrection.correct(arc, aspectRatio: 1) == nil)
    }

    @Test func repeatedStationarySamplesRemainAVisibleDot() {
        var ink = PresenterInk()
        let began = ink.begin(mode: .pen, smoothing: true, x: 0.5, y: 0.5)
        #expect(began)
        let moved = ink.move(x: 0.5, y: 0.5)
        #expect(moved)
        ink.end()
        #expect(ink.strokes[0].points.count == 2 && ink.strokes[0].isDot)
    }

}
