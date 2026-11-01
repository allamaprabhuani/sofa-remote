import AppKit
import ApplicationServices

/// Selects where remote pointer input lands; windows move only on an explicit request.
@MainActor
final class DisplayController {
    enum DisplayError: LocalizedError {
        case noDisplay, noWindow, accessibility, changedWindow, moveFailed, fullscreenFailed
        var errorDescription: String? {
            switch self {
            case .noDisplay: return "The selected display is no longer connected."
            case .noWindow: return "No foreground window is available to move."
            case .accessibility: return "Allow Sofa Remote in Privacy & Security > Accessibility."
            case .changedWindow: return "The foreground window changed; choose Move window again."
            case .moveFailed: return "The window could not be moved to the selected display."
            case .fullscreenFailed: return "The window did not complete its fullscreen transition."
            }
        }
    }

    private(set) var preferredID: String?

    init(preferredID: String? = nil) { self.preferredID = preferredID }

    static func displayID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else {
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return "display-\(number?.uint32Value ?? 0)"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    private static func number(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var target: NSScreen? {
        if let preferredID, let selected = NSScreen.screens.first(where: { Self.displayID($0) == preferredID }) { return selected }
        return NSScreen.screens.first(where: { Self.number($0).map { CGDisplayIsBuiltin($0) == 0 } ?? false })
            ?? NSScreen.main ?? NSScreen.screens.first
    }

    var selectedID: String? { target.map(Self.displayID) }
    var options: [[String: String]] { NSScreen.screens.map { ["id": Self.displayID($0), "name": $0.localizedName] } }

    @discardableResult
    func select(_ id: String) -> Bool {
        guard let screen = NSScreen.screens.first(where: { Self.displayID($0) == id }) else { return false }
        preferredID = id
        let rect = Self.quartzFrame(for: screen.frame, primaryHeight: NSScreen.screens.first?.frame.height ?? screen.frame.maxY)
        CGWarpMouseCursorPosition(CGPoint(x: rect.midX, y: rect.midY))
        return true
    }

    static func quartzFrame(for frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0, point.x.isFinite, point.y.isFinite else { return CGPoint(x: rect.midX, y: rect.midY) }
        return CGPoint(x: min(max(point.x, rect.minX), rect.maxX - 1),
                       y: min(max(point.y, rect.minY), rect.maxY - 1))
    }

    /// Project a Quartz point onto the nearest real display rect. Points already inside any
    /// display pass through unchanged (free crossing between adjacent monitors, including
    /// negative-coordinate secondaries). Points in a gap or past an outer edge snap to the
    /// nearest in-bounds pixel of the closest display rect.
    static func project(_ point: CGPoint, onto quartzFrames: [CGRect]) -> CGPoint {
        guard !quartzFrames.isEmpty else { return point }
        guard point.x.isFinite, point.y.isFinite else {
            let first = quartzFrames[0]
            return CGPoint(x: first.midX, y: first.midY)
        }
        for rect in quartzFrames where rect.contains(point) { return point }
        var best = CGPoint(x: quartzFrames[0].midX, y: quartzFrames[0].midY)
        var bestDistance = CGFloat.infinity
        for rect in quartzFrames where rect.width > 0 && rect.height > 0 {
            let clamped = clamp(point, to: rect)
            let dx = point.x - clamped.x, dy = point.y - clamped.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance { bestDistance = distance; best = clamped }
        }
        return best
    }

    /// Map a would-be cursor position to a pixel that is actually visible on some display.
    /// The selected display is a jump-to/window-move destination, not consulted here, so a
    /// swipe can freely cross monitors like a native trackpad.
    func clampQuartz(_ point: CGPoint) -> CGPoint {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return point }
        let frames = screens.map { Self.quartzFrame(for: $0.frame, primaryHeight: primaryHeight) }
        return Self.project(point, onto: frames)
    }

    /// Move the one window focused when this operation starts. Never switch to another window.
    func moveFrontWindow(authorized: @escaping () -> Bool = { true }) async throws {
        try Task.checkCancellation()
        guard authorized() else { throw CancellationError() }
        guard AXIsProcessTrusted() else { throw DisplayError.accessibility }
        guard let screen = target else { throw DisplayError.noDisplay }
        let screenID = Self.displayID(screen)
        guard let app = NSWorkspace.shared.frontmostApplication, !app.isTerminated else { throw DisplayError.noWindow }
        let processID = app.processIdentifier
        let axApp = AXUIElementCreateApplication(processID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { throw DisplayError.noWindow }
        let window = value as! AXUIElement
        let fullscreenKey = "AXFullScreen" as CFString
        let wasFullscreen = bool(window, fullscreenKey) ?? false
        var exitedFullscreen = false
        do {
            if wasFullscreen {
                try validate(app, axApp, window, authorized: authorized)
                guard AXUIElementSetAttributeValue(window, fullscreenKey, kCFBooleanFalse) == .success else { throw DisplayError.fullscreenFailed }
                exitedFullscreen = true
                try await waitFullscreen(false, app: app, axApp: axApp, window: window, authorized: authorized)
                try await Task.sleep(for: .milliseconds(500))
            }
            for _ in 0..<15 {
                try Task.checkCancellation()
                try validate(app, axApp, window, authorized: authorized)
                guard let destination = NSScreen.screens.first(where: { Self.displayID($0) == screenID }) else { throw DisplayError.noDisplay }
                let area = Self.quartzFrame(for: destination.visibleFrame,
                                             primaryHeight: NSScreen.screens.first?.frame.height ?? destination.frame.maxY)
                guard var currentSize = size(window) else { throw DisplayError.moveFailed }
                let scale = min(1, area.width / max(currentSize.width, 1), area.height / max(currentSize.height, 1))
                currentSize = CGSize(width: currentSize.width * scale, height: currentSize.height * scale)
                var point = CGPoint(x: area.midX - currentSize.width / 2, y: area.midY - currentSize.height / 2)
                guard let positionValue = AXValueCreate(.cgPoint, &point), let sizeValue = AXValueCreate(.cgSize, &currentSize) else { throw DisplayError.moveFailed }
                let resized = scale >= 1 || AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success
                try validate(app, axApp, window, authorized: authorized)
                let positioned = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue) == .success
                try await Task.sleep(for: .milliseconds(200))
                try validate(app, axApp, window, authorized: authorized)
                if positioned && resized, let actual = position(window), abs(actual.x - point.x) < 12, abs(actual.y - point.y) < 12 {
                    if wasFullscreen {
                        try validate(app, axApp, window, authorized: authorized)
                        guard AXUIElementSetAttributeValue(window, fullscreenKey, kCFBooleanTrue) == .success else { throw DisplayError.fullscreenFailed }
                        try await waitFullscreen(true, app: app, axApp: axApp, window: window, authorized: authorized)
                        exitedFullscreen = false
                        // Fullscreen may settle on a different screen; verify the actual window center.
                        guard let p = position(window), let s = size(window),
                              Self.quartzFrame(for: destination.frame, primaryHeight: NSScreen.screens.first?.frame.height ?? destination.frame.maxY)
                                .contains(CGPoint(x: p.x + s.width / 2, y: p.y + s.height / 2)) else { throw DisplayError.moveFailed }
                    }
                    return
                }
            }
            throw DisplayError.moveFailed
        } catch {
            if exitedFullscreen, !Task.isCancelled, authorized(), !app.isTerminated,
               (try? validate(app, axApp, window, authorized: authorized)) != nil {
                _ = AXUIElementSetAttributeValue(window, fullscreenKey, kCFBooleanTrue)
            }
            throw error
        }
    }

    private func validate(_ app: NSRunningApplication, _ axApp: AXUIElement, _ window: AXUIElement,
                          authorized: () -> Bool) throws {
        try Task.checkCancellation()
        guard authorized() else { throw CancellationError() }
        guard !app.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw DisplayError.changedWindow }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID(), CFEqual(focused, window) else { throw DisplayError.changedWindow }
    }

    private func waitFullscreen(_ expected: Bool, app: NSRunningApplication, axApp: AXUIElement, window: AXUIElement,
                                authorized: () -> Bool) async throws {
        for _ in 0..<30 {
            try Task.checkCancellation()
            try validate(app, axApp, window, authorized: authorized)
            if bool(window, "AXFullScreen" as CFString) == expected { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw DisplayError.fullscreenFailed
    }

    private func bool(_ window: AXUIElement, _ key: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, key, &value) == .success else { return nil }
        return value as? Bool
    }

    private func position(_ window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?, result = CGPoint.zero
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetValue(value as! AXValue, .cgPoint, &result) else { return nil }
        return result
    }

    private func size(_ window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?, result = CGSize.zero
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetValue(value as! AXValue, .cgSize, &result) else { return nil }
        return result
    }
}
