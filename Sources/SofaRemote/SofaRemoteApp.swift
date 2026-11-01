import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins
import ServiceManagement
import Combine

// Select the property-wrapper type on SDKs that also export a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

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
    private var item: NSStatusItem?
    private var modelChanges: AnyCancellable?
    private var helpWindow: NSWindow?
    private var practiceWindow: NSWindow?
    private var window: NSWindow?
    private var fixture: InputFixture?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Sofa Remote…", action: #selector(show), keyEquivalent: ",").target = self
        if CommandLine.arguments.contains("--input-fixture") {
            appMenu.addItem(withTitle: "Input test window", action: #selector(showFixture), keyEquivalent: "t").target = self
        }
        appMenu.addItem(withTitle: "About & Help…", action: #selector(showHelp), keyEquivalent: "?").target = self
        appMenu.addItem(withTitle: "Check for updates…", action: #selector(checkUpdates), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Sofa Remote", action: #selector(quit), keyEquivalent: "q").target = self
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let windows = NSMenu(title: "Window")
        windows.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowsItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowsItem.submenu = windows; main.addItem(windowsItem); NSApp.windowsMenu = windows
        NSApp.mainMenu = main
        updateMenuBarVisibility()
        modelChanges = model.objectWillChange.sink { [weak self] _ in
            // ObservableObject emits before mutation; apply persisted visibility on the next turn.
            DispatchQueue.main.async { self?.updateMenuBarVisibility() }
        }
        model.startSharing()
        if model.devices.isEmpty || CommandLine.arguments.contains("--show") { show() }
        if CommandLine.arguments.contains("--input-fixture") {
            showFixture()
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        // Refresh permission/status text after the owner returns from System Settings.
        model.objectWillChange.send()
    }
    @objc private func show() {
        if window == nil {
            let view = SetupView(model: model, showHelp: { [weak self] in self?.showHelp() })
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
    /// A hidden status item must never make the running helper impossible to find.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return true
    }
    private func updateMenuBarVisibility() {
        guard model.showMenuBarIcon else {
            if let item { NSStatusBar.system.removeStatusItem(item); self.item = nil }
            return
        }
        if let item {
            item.menu?.item(at: 1)?.title = model.sharing ? "Stop sharing" : "Start sharing"
            item.button?.toolTip = model.sharing ? "Sofa Remote — sharing" : "Sofa Remote — sharing stopped"
            return
        }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Sofa Remote")
        status.button?.toolTip = "Sofa Remote — input only"
        let menu = NSMenu()
        menu.addItem(withTitle: "Sofa Remote…", action: #selector(show), keyEquivalent: "")
        menu.addItem(withTitle: model.sharing ? "Stop sharing" : "Start sharing", action: #selector(toggleSharing), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "About & Help…", action: #selector(showHelp), keyEquivalent: "")
        menu.addItem(withTitle: "Check for updates…", action: #selector(checkUpdates), keyEquivalent: "")
        menu.addItem(withTitle: "Hide menu-bar icon…", action: #selector(hideMenuBarIcon), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sofa Remote", action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        status.menu = menu
        item = status
    }
    @objc private func hideMenuBarIcon() {
        show()
        do { try model.setShowMenuBarIcon(false) }
        catch { model.message = "Could not save menu-bar visibility." }
    }
    @objc private func checkUpdates() { NSWorkspace.shared.open(SupportInfo.releases) }
    @objc private func showHelp() {
        if helpWindow == nil {
            let view = AboutHelpView(model: model, showPractice: { [weak self] in self?.showPractice() })
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 690),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = "About & Help — Sofa Remote"
            panel.minSize = NSSize(width: 440, height: 440)
            panel.contentView = NSHostingView(rootView: view)
            panel.isReleasedWhenClosed = false
            panel.center()
            helpWindow = panel
        }
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func showPractice() {
        if practiceWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = "Sofa Remote Practice"
            panel.minSize = NSSize(width: 360, height: 280)
            panel.contentView = NSHostingView(rootView: PracticeView())
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.center()
            practiceWindow = panel
        }
        practiceWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func toggleSharing() { if model.sharing { model.stopSharing() } else { model.startSharing() }; show() }
    @objc private func showFixture() {
        if fixture == nil { fixture = InputFixture(timing: { [weak model] in model?.inputTimingText ?? "Timing unavailable." }) }
        fixture?.show(on: model.displays.target)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === practiceWindow {
            practiceWindow?.contentView = nil
            practiceWindow = nil
            return
        }
        guard closing === window else { return }
        model.closePairing()
        window?.contentView = nil
        window = nil
    }
    func applicationWillTerminate(_ notification: Notification) { model.stopSharing() }
}

private struct SetupView: View {
    @ObservedObject var model: AppModel
    let showHelp: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "cursorarrow.rays").font(.system(size: 36)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sofa Remote").font(.largeTitle.bold())
                        Text("Control your Mac from your phone.")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text(SupportInfo.versionLabel).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("About & Help…", action: showHelp)
                }
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
                        Text("Use a trusted network. Local HTTP is unencrypted; paired phones can control this Mac.")
                            .font(.callout).foregroundStyle(.secondary)
                        if let code = model.pairingCode {
                            Text(code).font(.system(size: 34, weight: .semibold, design: .monospaced)).textSelection(.enabled)
                            if let expires = model.pairingExpires {
                                Text("Expires \(expires, style: .relative). Close this window to end pairing.").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.links, id: \.label) { link in
                                HStack(spacing: 18) {
                                    PairingQRCode(value: link.address + "/#pair=" + code).frame(width: 132, height: 132)
                                        .accessibilityLabel("Pairing QR code for \(link.label)")
                                        .accessibilityHint("Alternatively open the address beside this code on your phone and enter the pairing code.")
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
                if !model.devices.isEmpty {
                    GroupBox("Paired phones") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.devices, id: \.id) { device in
                                HStack { Text(device.name); Spacer(); Button("Remove") { model.revoke(device.id) }.accessibilityLabel("Remove paired phone \(device.name)") }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                }
                GroupBox("Preferences") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Keep Mac awake while sharing", isOn: Binding(get: { model.keepAwake }, set: {
                            do { try model.setKeepAwake($0) } catch { model.message = "Could not save the keep-awake setting." }
                        }))
                        Text("Prevents Mac sleep while sharing. Displays can still sleep.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("Show menu-bar icon", isOn: Binding(get: { model.showMenuBarIcon }, set: { value in
                            do { try model.setShowMenuBarIcon(value) }
                            catch { model.message = "Could not save menu-bar visibility." }
                        }))
                        Text("Open Sofa Remote from Applications to restore a hidden icon.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("Open at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval }, set: { value in
                            do {
                                if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                                model.message = SMAppService.mainApp.status == .requiresApproval ? "Allow Sofa Remote in System Settings → General → Login Items." : ""
                            } catch { model.message = "Could not change login item: \(error.localizedDescription)" }
                        }))
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                if !model.message.isEmpty { Text(model.message).font(.callout).textSelection(.enabled) }
                Divider()
                Text("Closing this window keeps sharing running. Stop sharing or Quit ends access.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Quit Sofa Remote") { NSApp.terminate(nil) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SetupInstructions: View {
    let showPractice: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Allow Accessibility on this Mac for mouse and keyboard control. Screen Recording is not needed.")
            Text("2. Connect your phone and Mac to the same trusted Wi-Fi, or your own Tailscale network. Choose Show pairing code and scan it with the phone Camera.")
            Text("3. Open the practice window below, then use your phone touchpad to move the pointer, tap Test click and try typing. The practice window saves no document.")
            Button("Open practice window", action: showPractice)
            Text("4. In iPhone Safari, choose Share → Add to Home Screen to keep the remote easy to find.")
            Text("Cannot connect? Keep the Mac awake, check Start sharing and the network, then scan a fresh QR. If permission was just enabled, reopen Sofa Remote. A changed Wi-Fi address may need a fresh Home Screen shortcut.")
            Link("Full setup and troubleshooting guide", destination: SupportInfo.setup)
        }.font(.callout).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PracticeView: View {
    @ViewState<Int> private var clicks = 0
    @ViewState<String> private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try your remote").font(.title2.bold())
            Text("Move the pointer here using your phone. Tap Test click, then select the text box and try the phone keyboard. Nothing is saved; closing this window clears the practice text.")
            HStack {
                Button("Test click") { clicks += 1 }
                Text("Clicks: \(clicks)").accessibilityLabel("Practice clicks: \(clicks)")
            }
            TextEditor(text: $text).font(.body)
                .accessibilityLabel("Practice typing area")
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
                .onChange(of: text) { _, value in if value.count > 1000 { text = String(value.prefix(1000)) } }
        }.padding(24)
    }
}

private struct AboutHelpView: View {
    @ObservedObject var model: AppModel
    let showPractice: () -> Void
    @ViewState<Bool> private var setupExpanded = false
    @ViewState<Bool> private var appeared = false
    @ViewState<String> private var summary = ""
    @ViewState<Bool> private var copied = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Sofa Remote").font(.largeTitle.bold())
                Text(SupportInfo.versionLabel).textSelection(.enabled)
                Text("By \(SupportInfo.developer) · Free and open source")
                DisclosureGroup("Setup and connection help", isExpanded: $setupExpanded) {
                    SetupInstructions(showPractice: showPractice).padding(.top, 8)
                }
                GroupBox("Help and feedback") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("Report a bug", destination: SupportInfo.bugReport)
                        Link("Suggest a feature", destination: SupportInfo.featureRequest)
                        Link("Questions and developer contact", destination: SupportInfo.discussions)
                        Link("Check for updates and release notes", destination: SupportInfo.releases)
                        Text("Opens GitHub on request. No update checks or reports run in the background.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("Diagnostic summary") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Versions, architecture and permission/sharing status only. No input, tokens, personal URLs, names or screenshots. Nothing is uploaded.")
                            .font(.callout)
                        if !summary.isEmpty {
                            Text(summary).font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Diagnostic summary preview")
                                .accessibilityValue(summary)
                        }
                        HStack {
                            Button(summary.isEmpty ? "Preview diagnostic summary" : "Refresh summary") { refreshSummary() }
                            Button(copied ? "Copied" : "Copy diagnostic summary") {
                                NSPasteboard.general.clearContents()
                                copied = NSPasteboard.general.setString(summary, forType: .string)
                            }.disabled(summary.isEmpty)
                        }
                        Text("Review the preview before copying it into a report.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("Privacy, security and credits") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Direct LAN HTTP is unencrypted. Use a trusted network or your own encrypted Tailscale connection. Stop sharing closes the listener; revoke a phone to remove its access.")
                        Link("Privacy", destination: SupportInfo.privacy)
                        Link("Report a vulnerability privately", destination: SupportInfo.security)
                        Link("MIT licence", destination: SupportInfo.licence)
                        Link("Credits and Mac TV attribution", destination: SupportInfo.credits)
                        Link("Source code and contributions", destination: SupportInfo.repository)
                        if let notices = SupportInfo.bundledNotices {
                            DisclosureGroup("Read bundled licences and credits offline") {
                                Text(notices).font(.caption).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.onAppear {
            if !appeared {
                setupExpanded = model.devices.isEmpty
                appeared = true
            }
        }
    }
    private func refreshSummary() {
        summary = SupportInfo.diagnosticSummary(accessibilityAllowed: model.accessibilityAllowed,
                                               sharing: model.sharing, inputPaused: model.inputPaused)
        copied = false
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
