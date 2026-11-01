import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins
import ServiceManagement

@main enum SofaRemoteApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(CommandLine.arguments.contains("--input-fixture") ? .regular : .accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var item: NSStatusItem!
    private var window: NSWindow?
    private var fixture: InputFixture?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Sofa Remote…", action: #selector(show), keyEquivalent: ",").target = self
        if CommandLine.arguments.contains("--input-fixture") {
            appMenu.addItem(withTitle: "Input test window", action: #selector(showFixture), keyEquivalent: "t").target = self
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Sofa Remote", action: #selector(quit), keyEquivalent: "q").target = self
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let windows = NSMenu(title: "Window")
        let windowsItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowsItem.submenu = windows; main.addItem(windowsItem); NSApp.windowsMenu = windows
        NSApp.mainMenu = main
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Sofa Remote")
        item.button?.toolTip = "Sofa Remote — input only"
        let menu = NSMenu()
        menu.addItem(withTitle: "Sofa Remote…", action: #selector(show), keyEquivalent: "")
        menu.addItem(withTitle: "Stop / start sharing", action: #selector(toggleSharing), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sofa Remote", action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        model.startSharing()
        if model.devices.isEmpty || CommandLine.arguments.contains("--show") { show() }
        if CommandLine.arguments.contains("--input-fixture") {
            showFixture()
        }
    }
    @objc private func show() {
        if window == nil {
            let view = SetupView(model: model)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Sofa Remote"
            window.minSize = NSSize(width: 520, height: 480)
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func toggleSharing() { if model.sharing { model.stopSharing() } else { model.startSharing() }; show() }
    @objc private func showFixture() {
        if fixture == nil { fixture = InputFixture(timing: { [weak model] in model?.inputTimingText ?? "Timing unavailable." }) }
        fixture?.show(on: model.displays.target)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) {
        model.closePairing()
        window?.contentView = nil
        window = nil
    }
    func applicationWillTerminate(_ notification: Notification) { model.stopSharing() }
}

private struct SetupView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "cursorarrow.rays").font(.system(size: 36)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sofa Remote").font(.largeTitle.bold())
                        Text("Your phone is the mouse and keyboard. Your Mac does the playing.")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Input only · No screen capture · No ads or accounts").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Label(model.sharing ? "Sharing\(model.port.map { " on port \($0)" } ?? "…")" : "Sharing stopped",
                          systemImage: model.sharing ? "circle.fill" : "circle")
                        .foregroundStyle(model.sharing ? .green : .secondary)
                    Spacer()
                    Button(model.sharing ? "Stop sharing" : "Start sharing") {
                        if model.sharing { model.stopSharing() } else { model.startSharing() }
                    }
                }
                if !model.accessibilityAllowed {
                    GroupBox("Allow mouse and keyboard control") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Enable Sofa Remote in Privacy & Security → Accessibility. Screen Recording is not needed.")
                            Button("Open Accessibility settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                }
                if model.inputPaused {
                    GroupBox("Input paused") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unlock your Mac or leave secure text input, then resume here. Wake screen does not unlock the Mac.")
                            Button("Resume input on this Mac") { model.resumeInputLocally() }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                }
                GroupBox("Pair your phone") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use a trusted home network. Direct Wi-Fi HTTP is unencrypted; the Tailscale link uses your encrypted tailnet. Each paired phone can control your desktop.")
                            .font(.callout).foregroundStyle(.secondary)
                        if let code = model.pairingCode {
                            Text(code).font(.system(size: 34, weight: .semibold, design: .monospaced)).textSelection(.enabled)
                            if let expires = model.pairingExpires {
                                Text("Expires \(expires, style: .relative). Close this window to end pairing.").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.links, id: \.label) { link in
                                HStack(spacing: 18) {
                                    PairingQRCode(value: link.address + "/#pair=" + code).frame(width: 132, height: 132)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(link.label).font(.headline)
                                        Text(link.address).textSelection(.enabled)
                                        Text("Scan with the phone camera. Add the page to your Home Screen.").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if model.links.isEmpty { Text("Connect to Wi-Fi or Tailscale to show a QR code.") }
                            Button("End pairing") { model.closePairing() }
                        } else {
                            Button("Show pairing code") { model.openPairing() }.buttonStyle(.borderedProminent)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("Paired phones") {
                    VStack(alignment: .leading, spacing: 10) {
                        if model.devices.isEmpty { Text("No paired phones yet.").foregroundStyle(.secondary) }
                        ForEach(model.devices, id: \.id) { device in
                            HStack { Text(device.name); Spacer(); Button("Remove") { model.revoke(device.id) } }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                Toggle("Keep Mac awake while sharing", isOn: Binding(get: { model.keepAwake }, set: {
                    do { try model.setKeepAwake($0) } catch { model.message = "Could not save the keep-awake setting." }
                }))
                Text("Allows display sleep. The Mac must stay awake for the phone to reach it.").font(.caption).foregroundStyle(.secondary)
                Toggle("Open at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval }, set: { value in
                    do {
                        if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        model.message = SMAppService.mainApp.status == .requiresApproval ? "Allow Sofa Remote in System Settings → General → Login Items." : ""
                    } catch { model.message = "Could not change login item: \(error.localizedDescription)" }
                }))
                if !model.message.isEmpty { Text(model.message).font(.callout).textSelection(.enabled) }
                Divider()
                Text("Free and open source · MIT licence\nClosing this window keeps sharing running. Stop sharing or Quit closes the listener.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PairingQRCode: View {
    let value: String
    var body: some View {
        Group {
            if let image = QRCodeImages.image(value) {
                Image(nsImage: image).interpolation(.none).resizable().scaledToFit()
                    .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 12))
            } else { Text("QR unavailable").font(.caption) }
        }
    }
}

/// Avoid encoding the same QR again on each countdown refresh. Cache stays small and local.
@MainActor private enum QRCodeImages {
    static var cache: [String: NSImage] = [:]
    static func image(_ value: String) -> NSImage? {
        if let image = cache[value] { return image }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: output.extent.width, height: output.extent.height))
        if cache.count >= 4 { cache.removeAll() }
        cache[value] = image
        return image
    }
}
