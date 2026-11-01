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
    private let awake = AwakeAssertion()
    private var server: RemoteServer?
    private var observers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var lastWake: TimeInterval = -.infinity
    private var controlGeneration = 0
    private var movingWindow = false
    private var openingApp = false
    private var pairTimer: Timer?

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
            MainActor.assumeIsolated { self?.screenSleeping = true; self?.input.reset() }
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
                                  onRevoke: { [weak self] in self?.invalidateInput() })
        self.server = server
        sharing = true
        server.start(ports: Array(8740...8749)) { [weak self] port in
            guard let self else { return }
            self.port = port
            self.awake.set(self.keepAwake)
            self.message = "Ready. Pair a phone to control this Mac."
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
    private func invalidateInput() { controlGeneration += 1; input.reset() }
    func setKeepAwake(_ value: Bool) throws {
        guard let preferences else { throw RemoteError("Settings are unavailable.") }
        try preferences.update { $0.keepAwake = value }
        awake.set(sharing && value); objectWillChange.send()
    }
    func state() -> [String: Any] {
        ["name": Host.current().localizedName ?? "Mac", "sharing": sharing,
         "accessibility": accessibilityAllowed, "sessionLocked": inputPaused, "screenSleeping": screenSleeping,
         "frontApp": inputPaused ? "" : (NSWorkspace.shared.frontmostApplication?.localizedName ?? ""),
         "displayID": displays.selectedID ?? "", "displays": displays.options,
         "shortcuts": (preferences?.saved.shortcuts ?? []).map(\.json), "keepAwake": keepAwake]
    }

    func route(_ request: HTTPRequest) async -> HTTPResponse? {
        let body = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
        guard request.method == "POST" else { return nil }
        guard sharing, !Task.isCancelled else { return .json(["error": "Sharing stopped or request cancelled."], status: "409 Conflict") }
        if inputPaused {
            input.reset()
            guard request.path == "/command", body["type"] as? String == "action", body["action"] as? String == "screenOn" else {
                return .json(["error": "Input is paused. Unlock the Mac, then use Resume input in Sofa Remote on the Mac if needed."], status: "403 Forbidden")
            }
        }
        do {
            switch request.path {
            case "/command":
                let command = try RemoteCommand(json: body)
                if screenSleeping, command != .action(.screenOff) { try wake() }
                switch command {
                case .action(.screenOn): try wake()
                case .action(.screenOff): invalidateInput(); try DisplayPower.sleepDisplays()
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
                default: try input.handle(command)
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
                    guard !openingApp else { throw RemoteError("Wait for the current app to open.") }
                    openingApp = true
                    defer { openingApp = false }
                    _ = try await NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
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
            objectWillChange.send()
            return .json(["ok": true])
        } catch is CancellationError {
            input.reset()
            return .json(["error": "The operation was cancelled."], status: "409 Conflict")
        } catch let error as RemoteError {
            return .json(["error": error.localizedDescription], status: "400 Bad Request")
        } catch {
            message = error.localizedDescription
            return .json(["error": "The operation failed. Check Sofa Remote on the Mac."], status: "500 Internal Server Error")
        }
    }
    private func wake() throws {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWake >= 0.5 else { return }
        guard DisplayPower.wake() else { throw RemoteError("macOS did not accept the display wake request.") }
        lastWake = now
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.open([url], withApplicationAt: brave, configuration: config) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } else if !NSWorkspace.shared.open(url) { throw RemoteError("Could not open the website in your browser.") }
    }
}
