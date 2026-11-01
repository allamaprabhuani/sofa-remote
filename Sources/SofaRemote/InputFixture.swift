import AppKit

/// Explicit opt-in, disposable target for contributors checking real input without user documents.
@MainActor final class InputFixture: NSObject {
    private var window: NSWindow?
    private let counter = NSTextField(labelWithString: "Clicks: 0")
    private var clicks = 0
    private let timing: () -> String
    private let timingLabel = NSTextField(labelWithString: "Move the pointer, then refresh timing.")
    init(timing: @escaping () -> String = { "Timing is unavailable." }) { self.timing = timing; super.init() }
    func show(on screen: NSScreen?) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Sofa Remote Input Test"
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 360))
        let label = NSTextField(labelWithString: "Disposable input test — no document is saved")
        label.frame = NSRect(x: 20, y: 320, width: 520, height: 22)
        let text = NSTextView(frame: NSRect(x: 20, y: 90, width: 520, height: 215))
        text.string = "Input test ready\n"
        text.font = .systemFont(ofSize: 18)
        text.autoresizingMask = [.width, .height]
        text.setAccessibilityLabel("Remote input test text")
        let button = NSButton(title: "Test click", target: self, action: #selector(clicked))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 20, y: 30, width: 160, height: 36)
        counter.frame = NSRect(x: 200, y: 36, width: 95, height: 24)
        let refresh = NSButton(title: "Refresh link timing", target: self, action: #selector(refreshTiming))
        refresh.bezelStyle = .rounded
        refresh.frame = NSRect(x: 320, y: 30, width: 210, height: 36)
        timingLabel.frame = NSRect(x: 20, y: 5, width: 520, height: 20)
        timingLabel.font = .systemFont(ofSize: 12)
        container.addSubview(label); container.addSubview(text); container.addSubview(button); container.addSubview(counter)
        container.addSubview(refresh); container.addSubview(timingLabel)
        window.contentView = container
        if let screen {
            let frame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: frame.midX - 280, y: frame.midY - 180))
        } else { window.center() }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(text)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func clicked() { clicks += 1; counter.stringValue = "Clicks: \(clicks)" }
    @objc private func refreshTiming() { timingLabel.stringValue = timing() }
}
