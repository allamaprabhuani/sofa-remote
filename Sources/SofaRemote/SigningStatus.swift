import Foundation
import Security

/// A coarse signature classification, not a trust, notarisation or permission verdict.
/// Uses public Code Signing Services on this process once. No certificate identities,
/// requirements, fingerprints or keychain contents are exposed or persisted.
enum SigningStatus: String, CaseIterable, Sendable {
    case adHoc = "ad-hoc"
    case certificateSigned = "certificate-signed"
    case unsigned
    case unknown

    static let current = inspectSelf()

    var label: String {
        switch self {
        case .adHoc: return "Ad hoc"
        case .certificateSigned: return "Certificate-signed"
        case .unsigned: return "Unsigned"
        case .unknown: return "Unknown"
        }
    }
    var permissionContinuityWarning: String? {
        switch self {
        case .adHoc:
            return "This build is ad-hoc signed and has no stable signing identity. Rebuilds or updates may require Accessibility permission again. Stable signing is needed for permission continuity."
        case .unsigned:
            return "This build is unsigned and has no stable signing identity. Rebuilds or updates may require Accessibility permission again. Stable signing is needed for permission continuity."
        case .certificateSigned, .unknown: return nil
        }
    }

    /// Keeps the interpretation deterministic and testable without changing signatures or trust.
    static func classify(status: OSStatus, flags: UInt32?, hasCertificates: Bool) -> SigningStatus {
        if status == errSecCSUnsigned { return .unsigned }
        guard status == errSecSuccess, let flags else { return .unknown }
        if flags & SecCodeSignatureFlags.adhoc.rawValue != 0 { return .adHoc }
        return hasCertificates ? .certificateSigned : .unknown
    }

    private static func inspectSelf() -> SigningStatus {
        var code: SecCode?
        let selfStatus = SecCodeCopySelf([], &code)
        guard selfStatus == errSecSuccess, let code else {
            return classify(status: selfStatus, flags: nil, hasCertificates: false)
        }
        var staticCode: SecStaticCode?
        let staticStatus = SecCodeCopyStaticCode(code, [], &staticCode)
        guard staticStatus == errSecSuccess, let staticCode else {
            return classify(status: staticStatus, flags: nil, hasCertificates: false)
        }
        var information: CFDictionary?
        let status = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
        let values = information as? [String: Any]
        let flags = (values?[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value
        let hasCertificates = !(values?[kSecCodeInfoCertificates as String] as? [Any] ?? []).isEmpty
        return classify(status: status, flags: flags, hasCertificates: hasCertificates)
    }
}
