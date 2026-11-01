import AppKit
import IOKit.hidsystem
import CoreGraphics
import Foundation
import Testing
@testable import SofaRemote

@Suite @MainActor struct InputTests {
    @Test func padTapsEmitImmediateNativeDoubleClickOnlyForSameDeviceAndPosition() throws {
        var events: [CGEvent] = []
        var now: TimeInterval = 1
        var pointer = CGPoint(x: 100, y: 100)
        let input = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true },
            secure: { false }, readPosition: { pointer }, clock: { now }, doubleClickInterval: { 0.5 })
        func states() -> [Int64] { events.map { $0.getIntegerValueField(.mouseEventClickState) } }
        try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1]) // First click does not wait for a possible second tap.
        now += 0.2; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1, 2, 2])
        events.removeAll(); now += 0.1
        try input.handle(.tap, tapSource: "phone-a")
        now += 0.6; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1, 1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        now += 0.1; try input.handle(.tap, tapSource: "phone-b")
        #expect(states() == [1, 1, 1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        pointer.x += 6; now += 0.1; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1, 1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        input.reset(); now += 0.1; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1, 1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        try input.handle(.key("a", [])); events.removeAll()
        now += 0.1; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        input.cancelTapSequence() // A managed action may change the focused app.
        now += 0.1; try input.handle(.tap, tapSource: "phone-a")
        #expect(states() == [1, 1, 1, 1])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        try input.handle(.move(2, 0)); now += 0.1
        try input.handle(.tap, tapSource: "phone-a")
        #expect(events.filter { $0.type != .mouseMoved }.map { $0.getIntegerValueField(.mouseEventClickState) } == [1, 1, 2, 2])
        events.removeAll(); input.reset(); now += 1
        try input.handle(.tap, tapSource: "phone-a")
        try input.handle(.move(10, 0)); try input.handle(.move(-10, 0)); now += 0.1
        try input.handle(.tap, tapSource: "phone-a")
        #expect(events.filter { $0.type != .mouseMoved }.map { $0.getIntegerValueField(.mouseEventClickState) } == [1, 1, 1, 1])
        #expect(try RemoteCommand(json: ["type": "tap"]) == .tap)
    }
    @Test func queuedSleepRechecksAuthorizationAndCancellation() async throws {
        for cancel in [false, true] {
            var finishFirst: CheckedContinuation<Void, Error>?
            var sleepCount = 0
            var authorized = true
            let power = DisplayPowerCoordinator(sleep: {
                sleepCount += 1
                if sleepCount == 1 { try await withCheckedThrowingContinuation { finishFirst = $0 } }
            }, wake: { true })
            let first = Task { try await power.sleepDisplays() }
            while finishFirst == nil { await Task.yield() }
            let queued = Task { try await power.sleepDisplays(isAllowed: { authorized }) }
            await Task.yield()
            if cancel { queued.cancel() } else { authorized = false }
            finishFirst?.resume()
            try await first.value
            do { try await queued.value; Issue.record("Stale sleep must fail") } catch {}
            #expect(sleepCount == 1)
            #expect(!power.sleepPending)
        }
    }

    @Test func newestDisplayIntentWinsWhileSleepIsRunning() async throws {
        var events: [String] = []
        var finishFirst: CheckedContinuation<Void, Error>?
        var sleepCount = 0
        let power = DisplayPowerCoordinator(sleep: {
            sleepCount += 1
            events.append("sleep \(sleepCount) started")
            if sleepCount == 1 { try await withCheckedThrowingContinuation { finishFirst = $0 } }
            events.append("sleep \(sleepCount) finished")
        }, wake: { events.append("wake"); return true })
        let first = Task { try await power.sleepDisplays() }
        while finishFirst == nil { await Task.yield() }
        let wake = Task { try await power.wake() }
        await Task.yield()
        let last = Task { try await power.sleepDisplays() }
        await Task.yield()
        finishFirst?.resume()
        try await first.value
        do { try await wake.value; Issue.record("Superseded wake should fail") } catch {}
        try await last.value
        #expect(events == ["sleep 1 started", "sleep 1 finished", "sleep 2 started", "sleep 2 finished"])
        #expect(!power.sleepPending)
    }

    @Test func wakeWaitsForPendingDisplaySleepEvenIfRequestIsCancelled() async throws {
        var events: [String] = []
        var finishSleep: CheckedContinuation<Void, Error>?
        let power = DisplayPowerCoordinator(sleep: {
            events.append("sleep started")
            try await withCheckedThrowingContinuation { finishSleep = $0 }
            events.append("sleep finished")
        }, wake: { events.append("wake"); return true })
        let request = Task { try await power.sleepDisplays() }
        while finishSleep == nil { await Task.yield() }
        request.cancel()
        let wake = Task { try await power.wake() }
        await Task.yield()
        #expect(events == ["sleep started"])
        #expect(power.sleepPending)
        finishSleep?.resume()
        try await wake.value
        _ = try? await request.value
        #expect(events == ["sleep started", "sleep finished", "wake"])
        #expect(!power.sleepPending)
    }

    @Test func failedDisplaySleepDoesNotBlockWake() async throws {
        var finishSleep: CheckedContinuation<Void, Error>?
        var wakes = 0
        let power = DisplayPowerCoordinator(sleep: {
            try await withCheckedThrowingContinuation { finishSleep = $0 }
        }, wake: { wakes += 1; return true })
        let request = Task { try await power.sleepDisplays() }
        while finishSleep == nil { await Task.yield() }
        let wake = Task { try await power.wake() }
        finishSleep?.resume(throwing: RemoteError("sleep failed"))
        try await wake.value
        do { try await request.value; Issue.record("Sleep failure must be reported") } catch {}
        #expect(wakes == 1)
        #expect(!power.sleepPending)
    }
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
    @Test func brightnessKeysEmitBalancedSystemEventsAndRespectInputGates() throws {
        var events: [CGEvent] = []
        let input = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { false })
        try input.handle(.action(.brightnessUp))
        try input.handle(.action(.brightnessDown))
        #expect(events.count == 4)
        let decoded = try events.map { try #require(NSEvent(cgEvent: $0)) }
        #expect(decoded.allSatisfy { $0.type == .systemDefined && $0.subtype.rawValue == 8 })
        #expect(decoded.map { ($0.data1 >> 16) & 0xffff } == [Int(NX_KEYTYPE_BRIGHTNESS_UP), Int(NX_KEYTYPE_BRIGHTNESS_UP), Int(NX_KEYTYPE_BRIGHTNESS_DOWN), Int(NX_KEYTYPE_BRIGHTNESS_DOWN)])
        #expect(decoded.map { ($0.data1 >> 8) & 0xff } == [0xa, 0xb, 0xa, 0xb])
        events.removeAll()
        let denied = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { false }, secure: { false })
        #expect(throws: RemoteError.self) { try denied.handle(.action(.brightnessUp)) }
        let secure = InputController(displays: DisplayController(), emit: { events.append($0) }, trusted: { true }, secure: { true })
        #expect(throws: RemoteError.self) { try secure.handle(.action(.brightnessDown)) }
        #expect(events.isEmpty)
    }

}
