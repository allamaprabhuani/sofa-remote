import AppKit
import Combine
import CoreFoundation
import ServiceManagement

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var sharing = false
    @Published private(set) var port: UInt16?
    @Published private(set) var pairingCode: String?
    @Published private(set) var pairingExpires: Date?
    @Published var message = ""
    @Published private(set) var screenSleeping = false
    @Published private(set) var locallyPaused = false
    let displays: DisplayController
    let store: PairingStore
    private let preferences: Preferences?
    private let input: InputController
    private let presenter = PresenterOverlay()
    private var presenterOwner: String?
    private var presenterLastActivity: TimeInterval = 0
    private var presenterGuard: Timer?
    private let awake = AwakeAssertion()
    private let displayPower = DisplayPowerCoordinator()
    private var server: RemoteServer?
    private var observers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var lastWake: TimeInterval = -.infinity
    private var controlGeneration = 0
    private var movingWindow = false
    private var openingApp = false
    private var pairTimer: Timer?
    private var motionTimes: [TimeInterval] = []
    private var motionDurations: [TimeInterval] = []
    private let inputDiagnosticsEnabled = CommandLine.arguments.contains("--input-fixture")
    var inputTimingText: String {
        guard let first = motionTimes.first, let last = motionTimes.last, motionTimes.count > 1, last > first else {
            return "Move the pointer continuously, then refresh timing."
        }
        let gaps = zip(motionTimes.dropFirst(), motionTimes).map { $0 - $1 }
        let sorted = gaps.sorted()
        let processing = motionDurations.reduce(0, +) / Double(max(1, motionDurations.count))
        return String(format: "Input %.0f/s · median gap %.0f ms · max %.0f ms · Mac %.1f ms",
                      Double(gaps.count) / (last - first), sorted[sorted.count / 2] * 1000,
                      (gaps.max() ?? 0) * 1000, processing * 1000)
    }

    init(folder: URL = AppData.folder) {
        var failure: String?
        do { preferences = try Preferences(folder: folder) }
        catch { preferences = nil; failure = "Settings could not be read. Your existing file was preserved. \(error.localizedDescription)" }
        displays = DisplayController(preferredID: preferences?.saved.preferredDisplay)
        input = InputController(displays: displays)
        store = PairingStore(folder: folder)
        if let failure { message = failure }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenSleeping = true; self?.invalidateInput() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenSleeping = false }
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sessionActive = false; self?.invalidateInput() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sessionActive = true; self?.objectWillChange.send() }
        })
    }
    var accessibilityAllowed: Bool { input.accessibilityAllowed }
    var keepAwake: Bool { preferences?.saved.keepAwake ?? false }
    var showMenuBarIcon: Bool { preferences?.saved.showMenuBarIcon ?? true }
    var inputPaused: Bool {
        locallyPaused || !sessionActive || input.secureInput || NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.loginwindow"
    }
    var devices: [PairingStore.Device] { store.activeDevices() }
    var links: [(label: String, address: String)] {
        guard let port else { return [] }
        return NetworkAddresses.links(port: port)
    }

    func startSharing() {
        guard !sharing, preferences != nil else { return }
        let server = RemoteServer(store: store, html: { RemotePage.html }, state: { [weak self] in self?.state() ?? [:] },
                                  route: { [weak self] in await self?.route($0) },
                                  onRevoke: { [weak self] in
                                      self?.invalidateInput()
                                      self?.objectWillChange.send()
                                  })
        self.server = server
        sharing = true
        server.start(ports: Array(8740...8749)) { [weak self] port in
            guard let self else { return }
            self.port = port
            self.awake.set(self.keepAwake)
            self.message = "Sharing is running. Choose Show pairing code to connect a phone."
        }
        // A port failure must not leave a misleading Sharing label forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak server] in
            guard let self, self.server === server, self.port == nil else { return }
            self.stopSharing(); self.message = "Could not open the local remote listener. Try Start sharing again."
        }
    }
    func stopSharing() {
        closePairing(); invalidateInput(); server?.stop(); server = nil
        sharing = false; port = nil; awake.set(false)
        message = "Sharing stopped. No remote listener is open."
    }
    func openPairing() {
        if !sharing { startSharing() }
        guard let invitation = server?.beginPairing() else { return }
        pairingCode = invitation.code; pairingExpires = invitation.expires
        pairTimer?.invalidate()
        pairTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let expiry = self.pairingExpires, Date() >= expiry { self.closePairing() }
                self.objectWillChange.send()
            }
        }
        pairTimer?.tolerance = 0.2
    }
    func closePairing() {
        pairTimer?.invalidate(); pairTimer = nil
        server?.endPairing(); pairingCode = nil; pairingExpires = nil
    }
    /// Invoked only from the native app, after the owner has unlocked and returned to it.
    func resumeInputLocally() {
        guard NSApp.isActive, !input.secureInput else { message = "Unlock the Mac and return to Sofa Remote first."; return }
        locallyPaused = false; sessionActive = true
        message = "Input resumed."
    }
    func revoke(_ id: String) {
        do { try store.revoke(id: id); invalidateInput(); objectWillChange.send() }
        catch { message = "Could not save device removal." }
    }
    private func stopPresenter() {
        presenterGuard?.invalidate(); presenterGuard = nil
        presenter.stop(); presenterOwner = nil
    }
    private func guardPresenter() {
        guard presenterGuard == nil else { return }
        presenterGuard = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.sharing || self.inputPaused || !self.accessibilityAllowed || !self.presenter.isVisible {
                    self.stopPresenter()
                }
            }
        }
        presenterGuard?.tolerance = 0.2
    }
    private func invalidateInput() { controlGeneration += 1; input.reset(); stopPresenter() }
    func setKeepAwake(_ value: Bool) throws {
        guard let preferences else { throw RemoteError("Settings are unavailable.") }
        try preferences.update { $0.keepAwake = value }
        awake.set(sharing && value); objectWillChange.send()
    }
    func setShowMenuBarIcon(_ value: Bool) throws {
        guard let preferences else { throw RemoteError("Settings are unavailable.") }
        try preferences.update { $0.showMenuBarIcon = value }
        objectWillChange.send()
    }
    func state() -> [String: Any] {
        if inputPaused || !accessibilityAllowed { stopPresenter() }
        return ["name": Host.current().localizedName ?? "Mac", "sharing": sharing,
         "appVersion": SupportInfo.version, "appBuild": SupportInfo.build,
         "macOSVersion": SupportInfo.macOSVersion, "signingStatus": SigningStatus.current.rawValue,
         "accessibility": accessibilityAllowed, "sessionLocked": inputPaused, "screenSleeping": screenSleeping,
         "frontApp": inputPaused ? "" : (NSWorkspace.shared.frontmostApplication?.localizedName ?? ""),
         "displayID": displays.selectedID ?? "", "displays": displays.options,
         "shortcuts": (preferences?.saved.shortcuts ?? []).map(\.json), "keepAwake": keepAwake]
    }

    func route(_ request: HTTPRequest) async -> HTTPResponse? {
        let body = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
        guard request.method == "POST" else { return nil }
        guard sharing, !Task.isCancelled else { return .json(["error": "Sharing stopped or request cancelled."], status: "409 Conflict") }
        // Actions outside the input controller can change the focused window or
        // display. They must not leave a previous tap eligible for double-click.
        if request.path != "/command" { input.cancelTapSequence() }
        if inputPaused {
            input.reset(); stopPresenter()
            guard request.path == "/command", body["type"] as? String == "action", body["action"] as? String == "screenOn" else {
                return .json(["error": "Input is paused. Unlock the Mac, then use Resume input in Sofa Remote on the Mac if needed."], status: "403 Forbidden")
            }
        }
        do {
            switch request.path {
            case "/presenter":
                guard accessibilityAllowed, !input.secureInput else {
                    stopPresenter()
                    throw RemoteError("Allow Accessibility access and leave secure input before presenting.")
                }
                guard let device = store.authenticate(request.headers["x-sofa-key"]) else {
                    throw RemoteError("Pair with the Mac first.")
                }
                let command = try PresenterCommand(json: body)
                let now = ProcessInfo.processInfo.systemUptime
                if presenterOwner != nil && now - presenterLastActivity >= 30 {
                    stopPresenter()
                }
                if let owner = presenterOwner, owner != device.id {
                    throw RemoteError("Another paired device is using the presenter tools.")
                }
                switch command.action {
                case .start:
                    guard let mode = command.mode.flatMap({ PresenterOverlay.Mode(rawValue: $0.rawValue) }),
                          let color = command.color.flatMap({ PresenterOverlay.Color(rawValue: $0.rawValue) }),
                          let display = command.display, let x = command.x, let y = command.y else {
                        throw RemoteError("Choose a presentation tool and display.")
                    }
                    guard presenter.begin(displayID: display, mode: mode, color: color, smoothing: command.smoothing,
                                          shapeCorrection: command.shapeCorrection, x: x, y: y) else {
                        throw RemoteError("Presenter tool is unavailable. Check the display and finish the previous gesture.")
                    }
                    presenterOwner = device.id; guardPresenter()
                case .move:
                    guard presenterOwner == device.id, presenter.move(x: command.x!, y: command.y!) else {
                        throw RemoteError("Presenter gesture ended. Touch the pad again.")
                    }
                case .end:
                    guard presenterOwner == device.id else { throw RemoteError("Start a presenter gesture first.") }
                    presenter.end()
                case .clear:
                    guard presenterOwner == device.id else { throw RemoteError("Start a presenter gesture first.") }
                    presenter.clear()
                case .undo:
                    guard presenterOwner == device.id else { throw RemoteError("Start a presenter gesture first.") }
                    presenter.undo()
                case .heartbeat:
                    guard presenterOwner == device.id, presenter.keepAlive() else {
                        stopPresenter(); throw RemoteError("Presenter tools timed out. Touch the pad to start again.")
                    }
                case .stop:
                    stopPresenter()
                }
                presenterLastActivity = now
            case "/command":
                let command = try RemoteCommand(json: body)
                if case .action = command { input.cancelTapSequence() }
                var measuredMotionStart: TimeInterval?
                if inputDiagnosticsEnabled {
                    switch command {
                    case .move(let dx, let dy), .drag(.move, let dx, let dy):
                        if dx == 0 && dy == 0 { break }
                        let now = ProcessInfo.processInfo.systemUptime
                        if let last = motionTimes.last, now - last > 2 {
                            motionTimes.removeAll(keepingCapacity: true)
                            motionDurations.removeAll(keepingCapacity: true)
                        }
                        measuredMotionStart = now
                        motionTimes.append(now)
                        if motionTimes.count > 40 { motionTimes.removeFirst() }
                    default: break
                    }
                }
                defer {
                    if let start = measuredMotionStart {
                        motionDurations.append(ProcessInfo.processInfo.systemUptime - start)
                        if motionDurations.count > 40 { motionDurations.removeFirst() }
                    }
                }
                if (screenSleeping || displayPower.sleepPending), command != .action(.screenOff), command != .action(.screenOn) {
                    try await wake()
                    // The Mac may lock, sharing may stop, or pairing may be
                    // revoked while waiting for a pending display sleep.
                    guard sharing, !Task.isCancelled, !inputPaused,
                          store.authenticate(request.headers["x-sofa-key"]) != nil else {
                        throw RemoteError("Input paused or connection ended. Reconnect after unlocking the Mac.")
                    }
                }
                switch command {
                case .action(.screenOn): try await wake()
                case .action(.screenOff):
                    invalidateInput(); lastWake = -.infinity
                    let credential = request.headers["x-sofa-key"]
                    let generation = controlGeneration
                    try await displayPower.sleepDisplays { [weak self] in
                        guard let self else { return false }
                        return self.sharing && !self.inputPaused && self.controlGeneration == generation && self.store.authenticate(credential) != nil
                    }
                case .action(.downloads): try openDownloads()
                case .action(.moveWindow):
                    guard accessibilityAllowed else { throw RemoteError("Allow Sofa Remote in Accessibility on the Mac.") }
                    guard !movingWindow else { throw RemoteError("Wait for the current window move to finish.") }
                    movingWindow = true
                    defer { movingWindow = false }
                    let generation = controlGeneration
                    let credential = request.headers["x-sofa-key"]
                    try await displays.moveFrontWindow { [weak self] in
                        guard let self else { return false }
                        return self.sharing && !self.inputPaused && self.controlGeneration == generation
                            && self.store.authenticate(credential) != nil
                    }
                case .action(.lock):
                    invalidateInput(); try input.handle(command); locallyPaused = true
                    message = "Input paused after Lock. Unlock the Mac and choose Resume input here."
                default:
                    let source = store.authenticate(request.headers["x-sofa-key"])?.id
                    if command == .tap, source == nil { throw RemoteError("Pair with the Mac first.") }
                    try input.handle(command, tapSource: source)
                }
            case "/display":
                guard accessibilityAllowed else { throw RemoteError("Allow Sofa Remote in Accessibility on the Mac.") }
                guard let id = body["id"] as? String, displays.options.contains(where: { $0["id"] == id }),
                      let preferences else { throw RemoteError("Choose a connected display.") }
                try preferences.update { $0.preferredDisplay = id }
                input.reset()
                guard displays.select(id) else { throw RemoteError("The display disconnected. Choose another display.") }
            case "/open":
                guard let url = body["url"] as? String else { throw RemoteError("Enter a website address.") }
                try await openWebsite(Preferences.website(url))
            case "/launch":
                guard let id = body["id"] as? String,
                      let item = preferences?.saved.shortcuts.first(where: { $0.id == id }) else { throw RemoteError("Choose a saved shortcut.") }
                switch item.kind {
                case .downloads: try openDownloads()
                case .website: try await openWebsite(Preferences.website(item.url ?? ""))
                case .app:
                    guard let bundleID = item.bundleID,
                          let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { throw RemoteError("This app is not installed on the Mac.") }
                    if bundleID == "com.brave.Browser" {
                        // Opening the app alone can activate Brave without showing any window.
                        // A local blank tab creates a visible browser window without a network request.
                        try await openWebsite(URL(string: "about:blank")!)
                    } else {
                        guard !openingApp else { throw RemoteError("Wait for the current app to open.") }
                        openingApp = true
                        defer { openingApp = false }
                        _ = try await NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
            case "/shortcuts/add":
                guard let name = body["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      name.count <= 60, let preferences, preferences.saved.shortcuts.count < 24 else { throw RemoteError("Enter a name (up to 60 characters). You can save up to 24 shortcuts.") }
                let item: Shortcut
                if let address = body["url"] as? String {
                    item = Shortcut(id: UUID().uuidString, name: name, kind: .website, url: try Preferences.website(address).absoluteString)
                } else if let bundleID = body["bundleID"] as? String,
                          NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                    item = Shortcut(id: UUID().uuidString, name: name, kind: .app, bundleID: bundleID)
                } else { throw RemoteError("Enter a website or the bundle ID of an installed app.") }
                try preferences.update { $0.shortcuts.append(item) }
            case "/shortcuts/remove":
                guard let id = body["id"] as? String, let preferences,
                      preferences.saved.shortcuts.contains(where: { $0.id == id }) else { throw RemoteError("Choose a saved shortcut.") }
                try preferences.update { $0.shortcuts.removeAll { $0.id == id } }
            case "/shortcuts/move":
                guard let id = body["id"] as? String, let offset = body["offset"] as? NSNumber,
                      CFGetTypeID(offset) != CFBooleanGetTypeID(), offset == -1 || offset == 1, let preferences,
                      let index = preferences.saved.shortcuts.firstIndex(where: { $0.id == id }),
                      preferences.saved.shortcuts.indices.contains(index + offset.intValue) else { throw RemoteError("The shortcut cannot move further in that direction.") }
                try preferences.update { $0.shortcuts.swapAt(index, index + offset.intValue) }
            case "/settings":
                guard let keep = body["keepAwake"] as? NSNumber, CFGetTypeID(keep) == CFBooleanGetTypeID() else { throw RemoteError("Choose whether to keep the Mac awake.") }
                try setKeepAwake(keep.boolValue)
            default: return nil
            }
            try Task.checkCancellation()
            // Pointer/key commands change the desktop, not this native setup view.
            // Avoid scheduling a SwiftUI redraw for every high-frequency input packet.
            if request.path != "/command" && request.path != "/presenter" { objectWillChange.send() }
            return .json(["ok": true])
        } catch is CancellationError {
            input.reset(); stopPresenter()
            return .json(["error": "The operation was cancelled."], status: "409 Conflict")
        } catch let error as RemoteError {
            return .json(["error": error.localizedDescription], status: "400 Bad Request")
        } catch {
            message = error.localizedDescription
            return .json(["error": "The operation failed. Check Sofa Remote on the Mac."], status: "500 Internal Server Error")
        }
    }
    private func wake() async throws {
        let now = ProcessInfo.processInfo.systemUptime
        guard displayPower.sleepPending || now - lastWake >= 0.5 else { return }
        try await displayPower.wake()
        lastWake = ProcessInfo.processInfo.systemUptime
    }
    private func openDownloads() throws {
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
              NSWorkspace.shared.open(folder) else { throw RemoteError("Could not open Downloads in Finder.") }
    }
    private func openWebsite(_ url: URL) async throws {
        guard !openingApp else { throw RemoteError("Wait for the current app to open.") }
        openingApp = true
        defer { openingApp = false }
        if let brave = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.brave.Browser") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.open([url], withApplicationAt: brave, configuration: config) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } else if !NSWorkspace.shared.open(url) { throw RemoteError("Could not open the website in your browser.") }
    }
}
