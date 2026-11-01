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

}
