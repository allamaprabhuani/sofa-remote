import AppKit
import ApplicationServices
import Carbon
import IOKit.pwr_mgt
import IOKit.hidsystem

/// Sends input like a physical mouse/keyboard. Never observes or records the user's input.
@MainActor final class InputController {
    private let displays: DisplayController
    private var dragging = false
    private var dragDeadline: DispatchWorkItem?
    private let emit: (CGEvent) -> Void
    private let trusted: () -> Bool
    private let secure: () -> Bool
    private let readPosition: () -> CGPoint
    private let clock: () -> TimeInterval
    private var pointerAnchor: CGPoint?
    private var lastObserved: CGPoint?
    private var recentTargets: [CGPoint] = []
    private var lastMoveTime = -TimeInterval.infinity
    init(displays: DisplayController, emit: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) },
         trusted: @escaping () -> Bool = { AXIsProcessTrusted() },
         secure: @escaping () -> Bool = { IsSecureEventInputEnabled() },
         readPosition: @escaping () -> CGPoint = { CGEvent(source: nil)?.location ?? .zero },
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.displays = displays; self.emit = emit; self.trusted = trusted; self.secure = secure
        self.readPosition = readPosition; self.clock = clock
    }
    var accessibilityAllowed: Bool { trusted() }
    var isDragging: Bool { dragging }
    /// Secure input is deliberately treated as unavailable, including secure password fields.
    var secureInput: Bool { secure() }

    func handle(_ command: RemoteCommand) throws {
        guard accessibilityAllowed else { throw RemoteError("Allow Sofa Remote in System Settings → Privacy & Security → Accessibility.") }
        guard !secureInput else { reset(); throw RemoteError("Input is paused while the Mac uses secure keyboard input.") }
        switch command {
        case .move(let dx, let dy): try move(dx: dx, dy: dy, drag: dragging)
        case .scroll(let dx, let dy):
            guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                      wheel1: Int32(-dy), wheel2: Int32(-dx), wheel3: 0) else { throw eventError }
            event.location = position; emit(event)
        case .click(let button, let count):
            reset(clearPointer: false)
            for index in 1...count {
                try mouse(button == .left ? .leftMouseDown : .rightMouseDown, button: button == .left ? .left : .right, count: index)
                try mouse(button == .left ? .leftMouseUp : .rightMouseUp, button: button == .left ? .left : .right, count: index)
            }
        case .drag(let phase, let dx, let dy):
            switch phase {
            case .start:
                reset(clearPointer: false); try mouse(.leftMouseDown); dragging = true; armDragDeadline()
            case .move:
                guard dragging else { throw RemoteError("Drag ended. Hold Drag again to start a new drag.") }
                try move(dx: dx, dy: dy, drag: true); armDragDeadline()
            case .end: reset(clearPointer: false)
            }
        case .text(let text):
            let target = NSWorkspace.shared.frontmostApplication?.processIdentifier
            for character in text {
                guard !secureInput, NSWorkspace.shared.frontmostApplication?.processIdentifier == target else {
                    throw RemoteError("The active app changed or opened secure input. Remaining text was not sent.")
                }
                var units = Array(String(character).utf16)
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { throw eventError }
                down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                emit(down); emit(up)
            }
        case .key(let key, let modifiers): try keyPress(key, modifiers: modifiers)
        case .action(let action):
            switch action {
            case .playPause: try mediaKey(16)
            case .previous: try mediaKey(18)
            case .next: try mediaKey(17)
            case .volumeUp: try mediaKey(0)
            case .volumeDown: try mediaKey(1)
            case .mute: try mediaKey(7)
            // Simulate the Mac's brightness keys; display support and targeting are
            // determined by macOS and the connected hardware, not this app.
            case .brightnessUp: try mediaKey(Int(NX_KEYTYPE_BRIGHTNESS_UP))
            case .brightnessDown: try mediaKey(Int(NX_KEYTYPE_BRIGHTNESS_DOWN))
            case .fullscreen: try keyPress("f", modifiers: ["control", "command"])
            case .appSwitcher: try keyPress("tab", modifiers: ["command"])
            case .spotlight: try keyPress("space", modifiers: ["command"])
            case .showDesktop:
                // macOS's standard Show Desktop shortcut. Users may customise it in System Settings.
                try postKey(103, flags: []) // F11
            case .lock: reset(); try keyPress("q", modifiers: ["control", "command"])
            default: throw RemoteError("This action is managed by Sofa Remote.")
            }
        }
    }
    func reset(clearPointer: Bool = true) {
        dragDeadline?.cancel(); dragDeadline = nil
        if dragging { try? mouse(.leftMouseUp); dragging = false }
        if clearPointer { clearPointerAnchor() }
    }
    private func clearPointerAnchor() {
        pointerAnchor = nil; lastObserved = nil; recentTargets.removeAll(keepingCapacity: true)
    }
    private var position: CGPoint {
        let observed = readPosition()
        defer { lastObserved = observed }
        guard let anchor = pointerAnchor, clock() - lastMoveTime <= 0.15 else {
            clearPointerAnchor(); return observed
        }
        func near(_ a: CGPoint, _ b: CGPoint) -> Bool { hypot(a.x - b.x, a.y - b.y) <= 1 }
        // Accept delayed observations of our own events, but immediately yield to a
        // physical mouse move that leaves the recent synthetic path.
        if let previous = lastObserved, !near(observed, previous), !recentTargets.contains(where: { near(observed, $0) }) {
            clearPointerAnchor(); return observed
        }
        return anchor
    }
    private var eventError: RemoteError { RemoteError("macOS could not create the input event.") }
    private func move(dx: Double, dy: Double, drag: Bool) throws {
        let current = position
        let next = displays.clampQuartz(CGPoint(x: current.x + dx, y: current.y + dy))
        guard let event = CGEvent(mouseEventSource: nil, mouseType: drag ? .leftMouseDragged : .mouseMoved,
                                  mouseCursorPosition: next, mouseButton: .left) else { throw eventError }
        pointerAnchor = next; lastMoveTime = clock()
        recentTargets.append(next)
        if recentTargets.count > 8 { recentTargets.removeFirst() }
        emit(event)
    }
    private func mouse(_ type: CGEventType, button: CGMouseButton = .left, count: Int = 1) throws {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: position, mouseButton: button) else { throw eventError }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        emit(event)
    }
    private func armDragDeadline() {
        dragDeadline?.cancel()
        let deadline = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.reset() } }
        dragDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: deadline)
    }
    private func keyPress(_ key: String, modifiers: Set<String>) throws {
        guard let code = Self.codes[key] else { throw RemoteError("Unknown key.") }
        var flags: CGEventFlags = []
        if modifiers.contains("command") { flags.insert(.maskCommand) }
        if modifiers.contains("control") { flags.insert(.maskControl) }
        if modifiers.contains("option") { flags.insert(.maskAlternate) }
        if modifiers.contains("shift") { flags.insert(.maskShift) }
        try postKey(code, flags: flags)
    }
    private func postKey(_ code: CGKeyCode, flags: CGEventFlags) throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { throw eventError }
        down.flags = flags; up.flags = flags
        emit(down); emit(up)
    }
    private func mediaKey(_ code: Int) throws {
        for down in [true, false] {
            let state = down ? 0xa : 0xb
            guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)), timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: (code << 16) | (state << 8), data2: -1)?.cgEvent else { throw eventError }
            emit(event)
        }
    }
    private static let codes: [String: CGKeyCode] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,
        "q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,
        "6":22,"5":23,"9":25,"7":26,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,
        "enter":36,"l":37,"j":38,"k":40,"n":45,"m":46,"tab":48,"space":49,
        "backspace":51,"escape":53,"delete":117,"left":123,"right":124,"down":125,"up":126,
    ]
}

/// Holds only idle-system-sleep prevention, never an assertion keeping the display lit.
final class AwakeAssertion {
    private var id: IOPMAssertionID?
    func set(_ enabled: Bool) {
        if !enabled, let id { IOPMAssertionRelease(id); self.id = nil }
        guard enabled, id == nil else { return }
        var value: IOPMAssertionID = 0
        if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Sofa Remote sharing" as CFString, &value) == kIOReturnSuccess { id = value }
    }
    deinit { set(false) }
}

enum DisplayPower {
    @discardableResult static func wake() -> Bool {
        var id: IOPMAssertionID = 0
        guard IOPMAssertionDeclareUserActivity("Sofa Remote wake" as CFString, kIOPMUserActiveLocal, &id) == kIOReturnSuccess else { return false }
        let acquired = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { IOPMAssertionRelease(acquired) }
        return true
    }
    static func sleepDisplays() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        // Fixed executable/argument; no shell and no system-sleep command.
        try process.run()
        // Do not block the main actor. Bound a stuck pmset before allowing a
        // queued wake through, so it cannot sleep the displays afterwards.
        let timeout = DispatchWorkItem {
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeout)
        await Task.detached { process.waitUntilExit() }.value
        timeout.cancel()
        guard process.terminationStatus == 0 else {
            throw RemoteError("macOS could not turn the displays off.")
        }
    }
}

/// Serializes display intent even when an HTTP request is cancelled.
private final class DisplayRequestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

@MainActor final class DisplayPowerCoordinator {
    private let sleep: () async throws -> Void
    private let wakeDisplay: () -> Bool
    private var pending: Task<Void, Error>?
    private var generation = 0
    var sleepPending: Bool { pending != nil }

    init(sleep: @escaping () async throws -> Void = { try await DisplayPower.sleepDisplays() },
         wake: @escaping () -> Bool = { DisplayPower.wake() }) {
        self.sleep = sleep; self.wakeDisplay = wake
    }
    func sleepDisplays(isAllowed: @escaping @MainActor () -> Bool = { true }) async throws {
        let cancellation = DisplayRequestCancellation()
        try await withTaskCancellationHandler {
            try await enqueue {
                guard !cancellation.isCancelled, isAllowed() else {
                    throw RemoteError("Display request ended before it could run.")
                }
                try await self.sleep()
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
    func wake() async throws {
        try await enqueue {
            guard self.wakeDisplay() else { throw RemoteError("macOS did not accept the display wake request.") }
        }
    }
    private func enqueue(_ action: @escaping @MainActor () async throws -> Void) async throws {
        let previous = pending
        generation += 1
        let started = generation
        let operation = Task {
            // A failed sleep must not prevent a later wake.
            if let previous { _ = try? await previous.value }
            guard self.generation == started else { throw RemoteError("Display request was superseded by a newer action.") }
            try await action()
        }
        pending = operation
        defer { if generation == started { pending = nil } }
        try await operation.value
    }
}
