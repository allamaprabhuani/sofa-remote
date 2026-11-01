import AppKit

enum AppData {
    static var folder: URL {
        if let value = ProcessInfo.processInfo.environment["SOFA_REMOTE_DATA_DIR"], value.hasPrefix("/") {
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sofa Remote", isDirectory: true)
    }
}

struct Shortcut: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case website, app, downloads }
    let id: String
    var name: String
    let kind: Kind
    var url: String?
    var bundleID: String?

    var json: [String: String] { ["id": id, "name": name, "kind": kind.rawValue] }
}

struct SavedPreferences: Codable {
    var shortcuts: [Shortcut] = [
        Shortcut(id: "browser", name: "Brave", kind: .app, bundleID: "com.brave.Browser"),
        Shortcut(id: "iina", name: "IINA", kind: .app, bundleID: "com.colliderli.iina"),
        Shortcut(id: "downloads", name: "Downloads", kind: .downloads),
    ]
    var preferredDisplay: String?
    var keepAwake = false
}

/// Saves a complete replacement before exposing it in memory; failed writes never look successful.
@MainActor final class Preferences {
    private let file: URL
    private(set) var saved: SavedPreferences
    init(folder: URL = AppData.folder) throws {
        file = folder.appendingPathComponent("settings.json")
        if FileManager.default.fileExists(atPath: file.path) {
            saved = try JSONDecoder().decode(SavedPreferences.self, from: Data(contentsOf: file))
        } else { saved = SavedPreferences() }
    }
    func update(_ edit: (inout SavedPreferences) throws -> Void) throws {
        var next = saved
        try edit(&next)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = file.deletingLastPathComponent().appendingPathComponent(".settings-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try JSONEncoder().encode(next).write(to: temporary, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        guard rename(temporary.path, file.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
        saved = next
    }
    static func website(_ address: String) throws -> URL {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard value.utf8.count <= 4096, let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
            throw RemoteError("Enter an HTTP or HTTPS website address.")
        }
        return url
    }
}

struct RemoteError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
