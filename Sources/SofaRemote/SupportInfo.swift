import Foundation

/// Public support destinations and an allowlisted, user-reviewed diagnostic summary.
/// Never pass the remote state dictionary, settings, URLs or request content into diagnostics.
enum SupportInfo {
    static let developer = "Allamaprabhu Ani"
    static let repository = URL(string: "https://github.com/allamaprabhuani/sofa-remote")!
    static let setup = repository.appendingPathComponent("blob/main/docs/SETUP.md")
    static let privacy = repository.appendingPathComponent("blob/main/docs/PRIVACY.md")
    static let licence = repository.appendingPathComponent("blob/main/LICENSE")
    static let credits = repository.appendingPathComponent("blob/main/NOTICE")
    static let releases = repository.appendingPathComponent("releases")
    static let discussions = repository.appendingPathComponent("discussions")
    static let security = repository.appendingPathComponent("security/advisories/new")
    static let bugReport = URL(string: repository.absoluteString + "/issues/new?template=bug_report.yml")!
    static let featureRequest = URL(string: repository.absoluteString + "/issues/new?template=feature_request.yml")!

    static let bundledNotices: String? = {
        guard let licence = bundledText("LICENSE"), let notice = bundledText("NOTICE") else { return nil }
        return licence + "\n\n" + notice
    }()
    private static func bundledText(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    static var version: String { bundleValue("CFBundleShortVersionString", fallback: "development") }
    static var build: String { bundleValue("CFBundleVersion", fallback: "local") }
    static var versionLabel: String { "Version \(version) (\(build))" }
    static var macOSVersion: String {
        let value = ProcessInfo.processInfo.operatingSystemVersion
        return "\(value.majorVersion).\(value.minorVersion).\(value.patchVersion)"
    }
    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    private static func bundleValue(_ key: String, fallback: String) -> String {
        safeVersion(Bundle.main.object(forInfoDictionaryKey: key) as? String ?? fallback)
    }
    private static func safeVersion(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+-")
        guard !value.isEmpty, value.utf8.count <= 48, value.unicodeScalars.allSatisfy(allowed.contains) else { return "unknown" }
        return value
    }
    static func diagnosticSummary(version: String = version, build: String = build,
                                  macOS: String = macOSVersion, architecture: String = architecture,
                                  accessibilityAllowed: Bool, sharing: Bool, inputPaused: Bool) -> String {
        let numeric = CharacterSet(charactersIn: "0123456789.")
        let os = !macOS.isEmpty && macOS.utf8.count <= 24 && macOS.unicodeScalars.allSatisfy(numeric.contains) ? macOS : "unknown"
        let arch = ["arm64", "x86_64"].contains(architecture) ? architecture : "unknown"
        return """
        Sofa Remote diagnostic summary
        App: \(safeVersion(version)) (\(safeVersion(build)))
        macOS: \(os)
        Architecture: \(arch)
        Accessibility: \(accessibilityAllowed ? "allowed" : "not allowed")
        Sharing: \(sharing ? "running" : "stopped")
        Input: \(inputPaused ? "paused" : "available")
        """
    }
}
