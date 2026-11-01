import Foundation
import Testing
@testable import SofaRemote

@Suite @MainActor struct PreferencesTests {
    private func folder() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("work/tests/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    @Test func savedOrderAndPreferencesSurviveReload() throws {
        let folder = try folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = try Preferences(folder: folder)
        try store.update { state in
            state.shortcuts.swapAt(0, 1)
            state.keepAwake = true
            state.showMenuBarIcon = false
            state.preferredDisplay = "saved-display-uuid"
        }
        let reloaded = try Preferences(folder: folder)
        #expect(reloaded.saved.shortcuts.first?.id == "iina")
        #expect(reloaded.saved.keepAwake)
        #expect(!reloaded.saved.showMenuBarIcon)
        #expect(reloaded.saved.preferredDisplay == "saved-display-uuid")
        let mode = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("settings.json").path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
    }
    @Test func previousSettingsDefaultToAVisibleMenuBarIcon() throws {
        let folder = try folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let original = Data(#"{"shortcuts":[],"keepAwake":true,"preferredDisplay":"old-display"}"#.utf8)
        try original.write(to: folder.appendingPathComponent("settings.json"))
        let store = try Preferences(folder: folder)
        #expect(store.saved.showMenuBarIcon)
        #expect(store.saved.keepAwake)
        #expect(store.saved.preferredDisplay == "old-display")
        #expect(store.saved.shortcuts.isEmpty)
        #expect(try Data(contentsOf: folder.appendingPathComponent("settings.json")) == original)
        try store.update { $0.showMenuBarIcon = false }
        #expect(!(try Preferences(folder: folder)).saved.showMenuBarIcon)
    }
    @Test func failedWriteKeepsPriorStateAndCorruptionIsPreserved() throws {
        let folder = try folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = try Preferences(folder: folder)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("settings.json"), withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try store.update { $0.keepAwake = true } }
        #expect(!store.saved.keepAwake)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("settings.json"))
        let bytes = Data("broken json".utf8)
        try bytes.write(to: folder.appendingPathComponent("settings.json"))
        #expect(throws: (any Error).self) { _ = try Preferences(folder: folder) }
        #expect(try Data(contentsOf: folder.appendingPathComponent("settings.json")) == bytes)
    }
    @Test func websiteValidationRejectsNonWebAndCredentialURLs() throws {
        #expect(try Preferences.website("youtube.com").absoluteString == "https://youtube.com")
        for bad in ["file:///etc/passwd", "javascript://alert(1)", "ftp://example.com", "https://user:secret@example.com"] {
            #expect(throws: RemoteError.self) { _ = try Preferences.website(bad) }
        }
    }
}

@Suite struct CommandValidationTests {
    @Test func acceleratedMovesStayBoundedWithoutRelaxingScrollLimits() throws {
        #expect(try RemoteCommand(json: ["type":"move", "dx":1000, "dy":-1000]) == .move(1000, -1000))
        #expect(try RemoteCommand(json: ["type":"drag", "phase":"move", "dx":-1000, "dy":1000]) == .drag(.move, -1000, 1000))
        #expect(try RemoteCommand(json: ["type":"scroll", "dx":300, "dy":-300]) == .scroll(300, -300))
        for json: [String: Any] in [
            ["type":"move", "dx":1001, "dy":0], ["type":"move", "dx":Double.infinity, "dy":0],
            ["type":"drag", "phase":"move", "dx":0, "dy":-1001],
            ["type":"scroll", "dx":301, "dy":0]
        ] { #expect(throws: RemoteError.self) { _ = try RemoteCommand(json: json) } }
    }

    @Test func brightnessActionsAreExplicitlyAllowlisted() throws {
        #expect(try RemoteCommand(json: ["type":"action", "action":"brightnessUp"]) == .action(.brightnessUp))
        #expect(try RemoteCommand(json: ["type":"action", "action":"brightnessDown"]) == .action(.brightnessDown))
        #expect(throws: RemoteError.self) { _ = try RemoteCommand(json: ["type":"action", "action":"setBrightness"]) }
    }

    @Test func rejectsMalformedInputAndPreservesUnicodeText() throws {
        #expect(try RemoteCommand(json: ["type": "text", "value": "Hello 👋 ಕನ್ನಡ"]) == .text("Hello 👋 ಕನ್ನಡ"))
        let invalid: [[String: Any]] = [
            ["type":"move", "dx":true, "dy":0], ["type":"move", "dx":Double.nan, "dy":0],
            ["type":"scroll", "dx":301, "dy":0], ["type":"click", "button":"left", "count":1.5],
            ["type":"key", "key":"a", "modifiers":["superuser"]], ["type":"action", "action":"unlock"],
            ["type":"text", "value":String(repeating: "x", count:1001)],
        ]
        for value in invalid { #expect(throws: RemoteError.self) { _ = try RemoteCommand(json: value) } }
    }
}
