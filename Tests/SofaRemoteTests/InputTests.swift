import CoreGraphics
import Testing
@testable import SofaRemote

@Suite @MainActor struct InputTests {
    @Test func permissionAndSecureInputAreEnforcedWithoutPosting() throws {
        var events: [CGEvent] = []
        let denied = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { false }, secure: { false })
        #expect(throws: RemoteError.self) { try denied.handle(.key("a", [])) }
        let secure = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { true })
        #expect(throws: RemoteError.self) { try secure.handle(.text("not sent")) }
        #expect(events.isEmpty)
    }
    @Test func clickKeyAndDragReleaseUseBalancedEvents() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { false })
        try input.handle(.click(.left, 2))
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp])
        #expect(events.last?.getIntegerValueField(.mouseEventClickState) == 2)
        events.removeAll()
        try input.handle(.key("l", ["command"]))
        #expect(events.map(\.type) == [.keyDown, .keyUp])
        #expect(events.allSatisfy { $0.flags.contains(.maskCommand) })
        events.removeAll()
        try input.handle(.drag(.start, 0, 0))
        try input.handle(.drag(.move, 20, 10))
        input.reset()
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
        #expect(!input.isDragging)
        #expect(throws: RemoteError.self) { try input.handle(.drag(.move, 0, 0)) }
    }
    @Test func lostDragTimesOutWithoutReplayingInput() async throws {
        var events: [CGEventType] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0.type) }, trusted: { true }, secure: { false })
        try input.handle(.drag(.start, 0, 0))
        try await Task.sleep(for: .milliseconds(3300))
        #expect(!input.isDragging)
        #expect(events == [.leftMouseDown, .leftMouseUp])
    }
    @Test func secureInputStartingDuringDragReleasesTheButton() throws {
        var secure = false
        var events: [CGEventType] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0.type) }, trusted: { true }, secure: { secure })
        try input.handle(.drag(.start, 0, 0))
        secure = true
        #expect(throws: RemoteError.self) { try input.handle(.key("a", [])) }
        #expect(!input.isDragging)
        #expect(events == [.leftMouseDown, .leftMouseUp])
    }
}
