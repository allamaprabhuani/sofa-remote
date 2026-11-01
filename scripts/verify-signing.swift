import Foundation
import Security

// Build/install guard, not app runtime. Only system-generated identities are accepted.
struct SigningFailure: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw SigningFailure(message: message) }
}
func checked(_ status: OSStatus, _ message: String) throws {
    try require(status == errSecSuccess, "\(message) (status \(status)).")
}
let strict = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
let information = SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation)
func requirementData(_ requirement: SecRequirement) throws -> Data {
    var result: CFData?
    try checked(SecRequirementCopyData(requirement, [], &result), "Cannot inspect signing requirement")
    guard let result else { throw SigningFailure(message: "Missing signing requirement data.") }
    return result as Data
}
struct Slice {
    let code: SecStaticCode
    let requirement: SecRequirement
    let requirementBytes: Data
    let certificate: Data?
    let flags: UInt32
    let timestamp: Bool
}
func slice(_ app: URL, architecture: String? = nil) throws -> Slice {
    var value: SecStaticCode?
    if let architecture {
        let attributes = [kSecCodeAttributeArchitecture as String: architecture] as CFDictionary
        try checked(SecStaticCodeCreateWithPathAndAttributes(app as CFURL, [], attributes, &value), "Cannot open architecture")
    } else {
        try checked(SecStaticCodeCreateWithPath(app as CFURL, [], &value), "Cannot open application")
    }
    guard let code = value else { throw SigningFailure(message: "Missing signed code.") }
    try checked(SecStaticCodeCheckValidity(code, strict, nil), "Application signature is invalid")
    var raw: CFDictionary?
    try checked(SecCodeCopySigningInformation(code, information, &raw), "Cannot inspect application signature")
    guard let info = raw as? [String: Any],
          info[kSecCodeInfoIdentifier as String] as? String == bundleID,
          let actualValue = info[kSecCodeInfoDesignatedRequirement as String],
          let implicitValue = info[kSecCodeInfoImplicitDesignatedRequirement as String] else {
        throw SigningFailure(message: "Wrong signing identifier or missing requirements.")
    }
    let actual = actualValue as! SecRequirement
    let implicit = implicitValue as! SecRequirement
    let bytes = try requirementData(actual)
    // Prevent identifier-only or permissive OR requirements, even if both versions accept them.
    try require(bytes == requirementData(implicit), "Custom signing requirements are not accepted; sign a fresh bundle without requirement overrides")
    let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
    return Slice(code: code, requirement: actual, requirementBytes: bytes,
                 certificate: certificates.first.map { SecCertificateCopyData($0) as Data },
                 flags: (info[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0,
                 timestamp: info[kSecCodeInfoTimestamp as String] != nil)
}
func architectures(_ app: URL) throws -> [String] {
    guard let bundle = Bundle(url: app), let executable = bundle.executableURL else {
        throw SigningFailure(message: "Missing application executable.")
    }
    let process = Process(), output = Pipe(), errors = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
    process.arguments = ["-archs", executable.path]
    process.standardOutput = output; process.standardError = errors
    try process.run()
    let bytes = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    try require(process.terminationStatus == 0, "Cannot inspect application architectures")
    let result = String(decoding: bytes, as: UTF8.self).split(whereSeparator: { $0.isWhitespace }).map(String.init).sorted()
    try require(!result.isEmpty && Set(result).isSubset(of: ["arm64", "x86_64"]), "Unexpected application architecture")
    return result
}
func inspect(_ app: URL, mode: String, releaseRequirement: SecRequirement?) throws -> [String: Slice] {
    var result: [String: Slice] = [:]
    let supportedArchitectures = try architectures(app)
    if mode == "release" || mode == "preview" {
        try require(Set(supportedArchitectures) == Set(["arm64", "x86_64"]), "Published downloads must include both Intel and Apple silicon")
    }
    for architecture in supportedArchitectures {
        let current = try slice(app, architecture: architecture)
        let adhoc = current.flags & SecCodeSignatureFlags.adhoc.rawValue != 0
        if mode == "development" {
            try require(adhoc && current.certificate == nil, "Development-artifact mode requires an explicitly ad-hoc signed bundle")
        } else {
            try require(!adhoc && current.certificate != nil, "Certificate signing is required; ad-hoc updates cannot retain permission")
        }
        if mode == "release" || mode == "preview" {
            try require(current.flags & SecCodeSignatureFlags.runtime.rawValue != 0, "Published apps require hardened runtime")
        }
        if let releaseRequirement {
            try checked(SecStaticCodeCheckValidity(current.code, strict, releaseRequirement), "Expected Developer ID, Team ID and bundle identity are required")
            try require(current.flags & SecCodeSignatureFlags.runtime.rawValue != 0, "Hardened runtime is required for publication")
            try require(current.timestamp, "A secure signing timestamp is required for publication")
        }
        result[architecture] = current
    }
    if mode != "development", let first = result.values.first {
        try require(result.values.allSatisfy { $0.certificate == first.certificate && $0.requirementBytes == first.requirementBytes }, "Architectures have different signing identities")
    }
    return result
}

var arguments = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    let value = arguments[index + 1]; arguments.removeSubrange(index...index + 1); return value
}
let mode = option("--mode") ?? "certificate"
let appPath = option("--app")
let previousPath = option("--previous")
let teamID = option("--team")
let bundleID = option("--bundle-id") ?? "org.sofaremote.mac"
do {
    try require(arguments.isEmpty && appPath != nil && ["certificate", "release", "preview", "development"].contains(mode), "Usage: verify-signing.sh --mode certificate|release|preview|development --app APP [--previous APP] [--team TEAM]")
    try require(bundleID.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil, "Invalid bundle identifier")
    var releaseRequirement: SecRequirement?
    if mode == "release" {
        try require(teamID?.range(of: #"^[A-Z0-9]{10}$"#, options: .regularExpression) != nil, "Set the expected publisher Team ID")
        // This is a verification constraint, never a replacement designated requirement.
        let predicate = "anchor apple generic and identifier \"\(bundleID)\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(teamID!)\""
        try checked(SecRequirementCreateWithString(predicate as CFString, [], &releaseRequirement), "Cannot create publisher verification constraint")
    }
    let app = URL(fileURLWithPath: appPath!).standardizedFileURL.resolvingSymlinksInPath()
    let next = try inspect(app, mode: mode, releaseRequirement: releaseRequirement)
    if let previousPath {
        try require(mode != "development", "Ad-hoc artifacts cannot claim update continuity")
        let previous = try inspect(URL(fileURLWithPath: previousPath).standardizedFileURL.resolvingSymlinksInPath(), mode: mode, releaseRequirement: releaseRequirement)
        try require(Set(previous.keys) == Set(next.keys), "Architecture changes need explicit migration review")
        for (architecture, old) in previous {
            let new = next[architecture]!
            try require(old.requirementBytes == new.requirementBytes, "Signing identity changed; stop installation and review migration before granting permission")
            try checked(SecStaticCodeCheckValidity(new.code, strict, old.requirement), "Update does not satisfy the previous identity")
            try checked(SecStaticCodeCheckValidity(old.code, strict, new.requirement), "Previous app does not satisfy the new identity")
        }
    }
    print(previousPath == nil ? "PASS signing policy (\(mode)); all architectures verified." : "PASS signing identity is unchanged across versions; all architectures verified.")
} catch let error as SigningFailure {
    FileHandle.standardError.write(Data(("Signing check failed: " + error.message + "\n").utf8)); exit(1)
} catch {
    FileHandle.standardError.write(Data("Signing check failed: cannot complete verification.\n".utf8)); exit(1)
}
