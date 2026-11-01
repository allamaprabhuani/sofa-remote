import Foundation
import CryptoKit
import Security
import Darwin

/// Stores only digests of independently generated 256-bit device secrets.
final class PairingStore {
    struct Device: Codable {
        let id: String
        let name: String
        let digest: String
    }
    private let file: URL
    private(set) var devices: [Device]
    private let readFailed: Bool

    init(folder: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Sofa Remote", isDirectory: true)) {
        file = folder.appendingPathComponent("paired-devices.json")
        if FileManager.default.fileExists(atPath: file.path) {
            if let data = try? Data(contentsOf: file), let loaded = try? JSONDecoder().decode([Device].self, from: data) {
                devices = loaded; readFailed = false
            } else { devices = []; readFailed = true }
        } else { devices = []; readFailed = false }
    }

    enum StoreError: Error { case deviceLimit }

    func issue(name: String) throws -> (token: String, deviceID: String) {
        guard devices.count < 16 else { throw StoreError.deviceLimit }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw CocoaError(.fileWriteUnknown) }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let device = Device(id: UUID().uuidString, name: trimmed.isEmpty ? "Phone" : trimmed, digest: digest(token))
        try save(devices + [device])
        return (token, device.id)
    }

    func authenticate(_ token: String?) -> Device? {
        guard let token, token.utf8.count == 64,
              token.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        let hash = digest(token)
        return devices.first { $0.digest == hash }
    }
    func activeDevices() -> [Device] { devices }
    func revoke(id: String) throws { try save(devices.filter { $0.id != id }) }
    func revokeAll() throws { try save([]) }

    private func digest(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func save(_ updated: [Device]) throws {
        guard !readFailed else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = file.deletingLastPathComponent().appendingPathComponent(".paired-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try JSONEncoder().encode(updated).write(to: temporary, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        guard rename(temporary.path, file.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        devices = updated
    }
}
