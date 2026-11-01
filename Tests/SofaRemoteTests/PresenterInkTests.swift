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
        #expect(ink.laser == nil && !ink.active)
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
        #expect(ink.strokes.count == 1 && ink.strokes[0].count == 2)
        ink.clear()
        #expect(ink.strokes.isEmpty && ink.laser == nil && !ink.active)
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
}
