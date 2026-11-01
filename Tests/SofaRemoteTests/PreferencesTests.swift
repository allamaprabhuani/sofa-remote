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
            state.preferredDisplay = "saved-display-uuid"
        }
        let reloaded = try Preferences(folder: folder)
        #expect(reloaded.saved.shortcuts.first?.id == "iina")
        #expect(reloaded.saved.keepAwake)
        #expect(reloaded.saved.preferredDisplay == "saved-display-uuid")
        let mode = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("settings.json").path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
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
