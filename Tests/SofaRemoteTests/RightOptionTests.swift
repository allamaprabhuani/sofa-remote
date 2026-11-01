import Testing
import AppKit
@testable import SofaRemote

@Suite struct RightOptionTests {
    @Test func validatesPhases() throws {
        #expect(try RemoteCommand(json: ["type":"rightOption", "phase":"start"]) == .rightOption(.start))
        #expect(try RemoteCommand(json: ["type":"rightOption", "phase":"heartbeat"]) == .rightOption(.heartbeat))
        #expect(throws: (any Error).self) { try RemoteCommand(json: ["type":"rightOption", "phase":"move"]) }
    }
    @Test @MainActor func holdIsOwnedAndResetReleases() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { false })
        try input.handle(.rightOption(.start), tapSource: "one")
        #expect(input.rightOptionHeld)
        #expect(events.count == 1 && events[0].type == .flagsChanged)
        #expect(events[0].getIntegerValueField(.keyboardEventKeycode) == 61)
        #expect(events[0].flags.contains(.maskAlternate))
        #expect((events[0].flags.rawValue & 0x40) != 0)
        #expect(throws: (any Error).self) { try input.handle(.rightOption(.end), tapSource: "other") }
        #expect(input.rightOptionHeld)
        try input.handle(.rightOption(.heartbeat), tapSource: "one")
        input.reset()
        #expect(!input.rightOptionHeld)
        #expect(events.count == 2 && events[1].type == .flagsChanged && !events[1].flags.contains(.maskAlternate))
    }
    @Test @MainActor func timeoutReleasesLostHold() async throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { false })
        try input.handle(.rightOption(.start), tapSource: "one")
        try await Task.sleep(for: .seconds(4.3))
        #expect(!input.rightOptionHeld)
        #expect(events.count == 2)
    }
}
