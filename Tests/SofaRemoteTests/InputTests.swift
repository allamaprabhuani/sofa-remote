import CoreGraphics
import Foundation
import Testing
@testable import SofaRemote

@Suite @MainActor struct InputTests {
    @Test func successiveMovesKeepFractionalTravelWhenSystemPositionLags() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) },
            trusted: { true }, secure: { false }, readPosition: { CGPoint(x: 100, y: 100) }, clock: { 1 })
        for _ in 0..<4 { try input.handle(.move(0.25, 0.25)) }
        #expect(events.last?.location == CGPoint(x: 101, y: 101))
        try input.handle(.click(.left, 1))
        #expect(events.suffix(2).allSatisfy { $0.location == CGPoint(x: 101, y: 101) })
    }

    @Test func pointerAnchorYieldsToPhysicalMovementAndIdle() throws {
        var events: [CGEvent] = []
        var actual = CGPoint(x: 100, y: 100), time: TimeInterval = 1
        let input = InputController(displays: DisplayController(), emit: { events.append($0) },
            trusted: { true }, secure: { false }, readPosition: { actual }, clock: { time })
        try input.handle(.move(10, 0))
        actual = CGPoint(x: 110, y: 100) // WindowServer catches up to our own event.
        try input.handle(.move(10, 0))
        #expect(events.last?.location == CGPoint(x: 120, y: 100))
        actual = CGPoint(x: 400, y: 200) // A physical mouse leaves the synthetic path.
        try input.handle(.move(5, 0))
        #expect(events.last?.location == CGPoint(x: 405, y: 200))
        time += 0.2; actual = CGPoint(x: 500, y: 200)
        try input.handle(.move(1, 0))
        #expect(events.last?.location == CGPoint(x: 501, y: 200))
        input.reset(); actual = CGPoint(x: 200, y: 200)
        try input.handle(.move(1, 0))
        #expect(events.last?.location == CGPoint(x: 201, y: 200))
    }

    @Test func buttonEventsDoNotDiscardPendingPointerPosition() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) },
            trusted: { true }, secure: { false }, readPosition: { CGPoint(x: 100, y: 100) }, clock: { 1 })
        try input.handle(.move(10, 0))
        try input.handle(.click(.left, 1))
        try input.handle(.move(5, 0))
        #expect(events.last?.location == CGPoint(x: 115, y: 100))
        try input.handle(.drag(.start, 0, 0))
        try input.handle(.drag(.move, 5, 0))
        try input.handle(.drag(.end, 0, 0))
        try input.handle(.move(5, 0))
        #expect(events.last?.location == CGPoint(x: 125, y: 100))
        input.reset()
        try input.handle(.move(1, 0))
        #expect(events.last?.location == CGPoint(x: 101, y: 100))
    }

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
    @Test func moveEmitsMouseMovedWithoutPostingWhenTrustDenied() throws {
        var events: [CGEvent] = []
        let denied = InputController(displays: DisplayController(), emit: { events.append($0) },
                                     trusted: { false }, secure: { false })
        #expect(throws: RemoteError.self) { try denied.handle(.move(10, -5)) }
        #expect(events.isEmpty)
    }

    @Test func moveWhileNotDraggingEmitsMouseMovedEventOnly() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) },
                                    trusted: { true }, secure: { false })
        try input.handle(.move(1, 1))
        #expect(events.count == 1)
        #expect(events.first?.type == .mouseMoved)
    }

    @Test func moveWhileDraggingEmitsLeftMouseDraggedForEachMotion() throws {
        var events: [CGEventType] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0.type) },
                                    trusted: { true }, secure: { false })
        try input.handle(.drag(.start, 0, 0))
        try input.handle(.drag(.move, 7, 3))
        try input.handle(.drag(.move, -2, 4))
        try input.handle(.drag(.end, 0, 0))
        #expect(events == [.leftMouseDown, .leftMouseDragged, .leftMouseDragged, .leftMouseUp])
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
