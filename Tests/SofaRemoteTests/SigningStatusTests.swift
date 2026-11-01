import Foundation
import Security
import Testing
@testable import SofaRemote

@Suite struct SigningStatusTests {
    @Test func signatureFactsMapToCoarseLabelsWithoutImplyingTrust() {
        let adhoc = SecCodeSignatureFlags.adhoc.rawValue
        #expect(SigningStatus.classify(status: errSecSuccess, flags: adhoc, hasCertificates: false) == .adHoc)
        #expect(SigningStatus.classify(status: errSecSuccess, flags: adhoc, hasCertificates: true) == .adHoc)
        #expect(SigningStatus.classify(status: errSecSuccess, flags: 0, hasCertificates: true) == .certificateSigned)
        #expect(SigningStatus.certificateSigned.label == "Certificate-signed")
        #expect(SigningStatus.classify(status: errSecCSUnsigned, flags: nil, hasCertificates: false) == .unsigned)
    }
    @Test func failedOrIncompleteInspectionDoesNotClaimAnIdentity() {
        #expect(SigningStatus.classify(status: errSecParam, flags: SecCodeSignatureFlags.adhoc.rawValue, hasCertificates: true) == .unknown)
        #expect(SigningStatus.classify(status: errSecSuccess, flags: nil, hasCertificates: true) == .unknown)
        #expect(SigningStatus.classify(status: errSecSuccess, flags: 0, hasCertificates: false) == .unknown)
    }
    @Test func continuityWarningIsSpecificToMissingSigningIdentity() {
        for status in [SigningStatus.adHoc, .unsigned] {
            let warning = status.permissionContinuityWarning ?? ""
            #expect(warning.contains("no stable signing identity"))
            #expect(warning.contains("may require Accessibility permission again"))
            #expect(!warning.contains("automatically grant"))
        }
        #expect(SigningStatus.certificateSigned.permissionContinuityWarning == nil)
        #expect(SigningStatus.unknown.permissionContinuityWarning == nil)
        #expect(Set(SigningStatus.allCases.map(\.rawValue)) == ["ad-hoc", "certificate-signed", "unsigned", "unknown"])
    }
}
