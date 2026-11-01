import Foundation
import Testing
@testable import SofaRemote

@Suite struct PresenterCommandTests {
    @Test func validActionsUseNormalizedFiniteCoordinates() throws {
        let command = try PresenterCommand(json: ["type":"presenter", "action":"start", "display":"display-1", "mode":"pen", "x":0.0, "y":1.0])
        #expect(command.action == .start && command.mode == .pen && command.color == .red && command.x == 0 && command.y == 1)
        #expect(try PresenterCommand(json: ["action":"heartbeat"]).action == .heartbeat)
        #expect(try PresenterCommand(json: ["action":"stop"]).action == .stop)
        for bad: Any in [true, -0.01, 1.01, Double.infinity, Double.nan, "0.4"] {
            #expect(throws: (any Error).self) { try PresenterCommand(json: ["action":"move", "x":bad, "y":0.5]) }
        }
    }
    @Test func rejectsUnrecognizedActionsToolsAndDisplays() {
        #expect(throws: (any Error).self) { try PresenterCommand(json: ["action":"run"]) }
        #expect(throws: (any Error).self) { try PresenterCommand(json: ["action":"start", "display":"", "mode":"pen", "x":0.5, "y":0.5]) }
        #expect(throws: (any Error).self) { try PresenterCommand(json: ["action":"start", "display":"screen", "mode":"shell", "x":0.5, "y":0.5]) }
        #expect(throws: (any Error).self) { try PresenterCommand(json: ["action":"start", "display":"screen", "mode":"highlight", "color":"invalid", "x":0.5, "y":0.5]) }
        let highlight = try? PresenterCommand(json: ["action":"start", "display":"screen", "mode":"highlight", "color":"blue", "x":0.5, "y":0.5])
        #expect(highlight?.mode == .highlight && highlight?.color == .blue)
    }
}
