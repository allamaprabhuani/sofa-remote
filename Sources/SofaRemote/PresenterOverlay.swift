import AppKit

/// Transient drawing state. Coordinates are normalized to a selected display,
/// with the origin at the top-left. No slide image or screen content is read.
struct PresenterInk {
    struct Stroke {
        let id: UUID
        let mode: PresenterOverlay.Mode
        let color: PresenterOverlay.Color
        var points: [CGPoint]
    }
    static let maxStrokes = 100
    static let maxPoints = 10_000
    private(set) var strokes: [Stroke] = []
    private(set) var cursor: CGPoint?
    private(set) var cursorColor: PresenterOverlay.Color = .red
    private(set) var active = false
    private(set) var mode: PresenterOverlay.Mode = .laser
    private var count = 0

    private static func point(_ x: Double, _ y: Double) -> CGPoint? {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
        return CGPoint(x: x, y: y)
    }
    mutating func begin(mode: PresenterOverlay.Mode, color: PresenterOverlay.Color = .red, x: Double, y: Double) -> Bool {
        guard !active, let point = Self.point(x, y) else { return false }
        if mode != .laser {
            guard strokes.count < Self.maxStrokes, count < Self.maxPoints else { return false }
            strokes.append(Stroke(id: UUID(), mode: mode, color: color, points: [point])); count += 1
        }
        cursor = point; cursorColor = color; self.mode = mode; active = true
        return true
    }
    mutating func move(x: Double, y: Double) -> Bool {
        guard active, let point = Self.point(x, y) else { return false }
        if mode != .laser {
            guard count < Self.maxPoints, !strokes.isEmpty else { return false }
            strokes[strokes.count - 1].points.append(point); count += 1
        }
        cursor = point
        return true
    }
    /// Returns a finished highlighter's unique ID for delayed removal.
    @discardableResult
    mutating func end() -> UUID? {
        let id = active && mode == .highlight ? strokes.last?.id : nil
        active = false; cursor = nil
        return id
    }
    @discardableResult
    mutating func undo() -> UUID? {
        end()
        guard let removed = strokes.popLast() else { return nil }
        count -= removed.points.count
        return removed.id
    }
    mutating func clear() { strokes.removeAll(); count = 0; end() }
    /// Only finished highlighter marks expire; persistent pens and active strokes survive.
    @discardableResult
    mutating func expireHighlight(id: UUID) -> Bool {
        guard let index = strokes.firstIndex(where: { $0.id == id && $0.mode == .highlight }),
              !(active && mode == .highlight && index == strokes.count - 1) else { return false }
        count -= strokes[index].points.count
        strokes.remove(at: index)
        return true
    }
}

/// Click-through, nonactivating overlay on one selected display. The caller
/// must enforce authentication, device ownership, Accessibility and secure-input
/// policy before every operation, and call stop when sharing or presenting ends.
@MainActor final class PresenterOverlay {
    enum Mode: String { case laser, pen, highlight }
    enum Color: String, CaseIterable {
        case red, blue, green, yellow
        var inkColor: NSColor {
            switch self {
            case .red: return .systemRed
            case .blue: return .systemBlue
            case .green: return .systemGreen
            case .yellow: return .systemYellow
            }
        }
    }
    private var ink = PresenterInk()
    private var panel: NSPanel?
    private var canvas: PresenterCanvas?
    private var selectedDisplay: String?
    private var expiry: DispatchWorkItem?
    private var highlightExpiries: [UUID: DispatchWorkItem] = [:]
    private var observers: [NSObjectProtocol] = []
    var isVisible: Bool { panel?.isVisible == true }

    @discardableResult
    func begin(displayID: String, mode: Mode, color: Color = .red, x: Double, y: Double) -> Bool {
        guard let screen = NSScreen.screens.first(where: { DisplayController.displayID($0) == displayID }) else { return false }
        // Validate before creating any window or discarding existing marks.
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y), !ink.active else { return false }
        if selectedDisplay != displayID { stop(); selectedDisplay = displayID }
        guard ink.begin(mode: mode, color: color, x: x, y: y) else { return false }
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
    func end() {
        if let id = ink.end() {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.highlightExpiries.removeValue(forKey: id)
                    if self.ink.expireHighlight(id: id) { self.render() }
                }
            }
            highlightExpiries[id] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
        }
        render(); renewExpiry()
    }
    func clear() {
        for work in highlightExpiries.values { work.cancel() }
        highlightExpiries.removeAll(); ink.clear(); render(); renewExpiry()
    }
    func undo() {
        if let id = ink.undo() { highlightExpiries.removeValue(forKey: id)?.cancel() }
        render(); renewExpiry()
    }
    func stop() {
        expiry?.cancel(); expiry = nil
        for work in highlightExpiries.values { work.cancel() }
        highlightExpiries.removeAll()
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
        for stroke in ink.strokes where !stroke.points.isEmpty {
            let color = stroke.mode == .highlight ? stroke.color.inkColor.withAlphaComponent(0.45) : stroke.color.inkColor
            color.setStroke(); color.setFill()
            let width: CGFloat = stroke.mode == .highlight ? 14 : 4
            let path = NSBezierPath(); path.lineWidth = width
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.move(to: position(stroke.points[0]))
            if stroke.points.count == 1 {
                let p = position(stroke.points[0])
                NSBezierPath(ovalIn: NSRect(x: p.x - width / 2, y: p.y - width / 2, width: width, height: width)).fill()
            } else {
                for p in stroke.points.dropFirst() { path.line(to: position(p)) }
                path.stroke()
            }
        }
        if let point = ink.cursor {
            let p = position(point)
            func dot(_ radius: CGFloat, _ color: NSColor) {
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)).fill()
            }
            dot(10, .white); dot(8, .black); dot(6, ink.cursorColor.inkColor)
        }
    }
}
