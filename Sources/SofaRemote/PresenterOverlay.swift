import AppKit

/// Transient drawing state. Coordinates are normalized to a selected display,
/// with the origin at the top-left. No slide image or screen content is read.
struct PresenterInk {
    static let maxStrokes = 100
    static let maxPoints = 10_000
    private(set) var strokes: [[CGPoint]] = []
    private(set) var laser: CGPoint?
    private(set) var active = false
    private(set) var mode: PresenterOverlay.Mode = .laser
    private var count = 0

    private static func point(_ x: Double, _ y: Double) -> CGPoint? {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
        return CGPoint(x: x, y: y)
    }
    mutating func begin(mode: PresenterOverlay.Mode, x: Double, y: Double) -> Bool {
        guard !active, let point = Self.point(x, y) else { return false }
        if mode == .pen {
            guard strokes.count < Self.maxStrokes, count < Self.maxPoints else { return false }
            strokes.append([point]); count += 1
        } else { laser = point }
        self.mode = mode; active = true
        return true
    }
    mutating func move(x: Double, y: Double) -> Bool {
        guard active, let point = Self.point(x, y) else { return false }
        if mode == .laser { laser = point }
        else {
            guard count < Self.maxPoints, !strokes.isEmpty else { return false }
            strokes[strokes.count - 1].append(point); count += 1
        }
        return true
    }
    mutating func end() { active = false; laser = nil }
    mutating func undo() {
        end()
        guard let removed = strokes.popLast() else { return }
        count -= removed.count
    }
    mutating func clear() { strokes.removeAll(); count = 0; end() }
}

/// Click-through, nonactivating overlay on one selected display. The caller
/// must enforce authentication, device ownership, Accessibility and secure-input
/// policy before every operation, and call stop when sharing or presenting ends.
@MainActor final class PresenterOverlay {
    enum Mode: String { case laser, pen }
    private var ink = PresenterInk()
    private var panel: NSPanel?
    private var canvas: PresenterCanvas?
    private var selectedDisplay: String?
    private var expiry: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    var isVisible: Bool { panel?.isVisible == true }

    @discardableResult
    func begin(displayID: String, mode: Mode, x: Double, y: Double) -> Bool {
        guard let screen = NSScreen.screens.first(where: { DisplayController.displayID($0) == displayID }) else { return false }
        // Validate before creating any window or discarding existing marks.
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y), !ink.active else { return false }
        if selectedDisplay != displayID { stop(); selectedDisplay = displayID }
        guard ink.begin(mode: mode, x: x, y: y) else { return false }
        if panel == nil { install(on: screen) }
        render(); renewExpiry()
        return true
    }
    @discardableResult
    func move(x: Double, y: Double) -> Bool {
        guard panel != nil, ink.move(x: x, y: y) else { return false }
        render(); renewExpiry(); return true
    }
    /// Only an authenticated presenter owner may renew this timeout.
    @discardableResult
    func keepAlive() -> Bool {
        guard panel != nil else { return false }
        renewExpiry(); return true
    }
    func end() { ink.end(); render(); renewExpiry() }
    func clear() { ink.clear(); render(); renewExpiry() }
    func undo() { ink.undo(); render(); renewExpiry() }
    func stop() {
        expiry?.cancel(); expiry = nil
        ink.clear(); canvas = nil
        panel?.orderOut(nil); panel?.close(); panel = nil
        selectedDisplay = nil
        for token in observers { NotificationCenter.default.removeObserver(token); NSWorkspace.shared.notificationCenter.removeObserver(token) }
        observers.removeAll()
    }
    private func install(on screen: NSScreen) {
        let p = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
        p.ignoresMouseEvents = true; p.isReleasedWhenClosed = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = PresenterCanvas(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]; p.contentView = view
        panel = p; canvas = view
        let hide: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main, using: hide))
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: hide))
        p.orderFrontRegardless()
    }
    private func render() { canvas?.ink = ink; canvas?.needsDisplay = true }
    private func renewExpiry() {
        guard panel != nil else { return }
        expiry?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.stop() } }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }
}

@MainActor private final class PresenterCanvas: NSView {
    var ink = PresenterInk()
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        func position(_ p: CGPoint) -> NSPoint { NSPoint(x: p.x * bounds.width, y: p.y * bounds.height) }
        NSColor.systemRed.setStroke()
        for stroke in ink.strokes where !stroke.isEmpty {
            let path = NSBezierPath(); path.lineWidth = 4
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.move(to: position(stroke[0]))
            if stroke.count == 1 {
                let p = position(stroke[0]); NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)).fill()
            } else {
                for p in stroke.dropFirst() { path.line(to: position(p)) }
                path.stroke()
            }
        }
        if let point = ink.laser {
            let p = position(point)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)).fill()
        }
    }
}
