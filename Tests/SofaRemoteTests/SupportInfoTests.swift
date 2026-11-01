import Foundation
import Testing
@testable import SofaRemote

@Suite struct SupportInfoTests {
    @Test func diagnosticSummaryContainsOnlyTheDocumentedFields() {
        let summary = SupportInfo.diagnosticSummary(version: "0.1.0-beta.1", build: "7", macOS: "15.1.0", architecture: "arm64",
                                                    accessibilityAllowed: true, sharing: false, inputPaused: true)
        #expect(summary == """
        Sofa Remote diagnostic summary
        App: 0.1.0-beta.1 (7)
        macOS: 15.1.0
        Architecture: arm64
        Accessibility: allowed
        Sharing: stopped
        Input: paused
        """)
        #expect(!summary.contains("http"))
        #expect(!summary.contains("token"))
        #expect(!summary.contains("name"))
    }
    @Test func diagnosticValuesCannotInjectOtherFields() {
        let summary = SupportInfo.diagnosticSummary(version: "0.1\nToken: secret", build: "https://personal.example",
                                                    macOS: "https://personal.example", architecture: "Personal Mac",
                                                    accessibilityAllowed: false, sharing: true, inputPaused: false)
        #expect(summary.contains("App: unknown (unknown)"))
        #expect(summary.contains("macOS: unknown"))
        #expect(summary.contains("Architecture: unknown"))
        #expect(!summary.contains("personal"))
        #expect(!summary.contains("secret"))
        #expect(!summary.contains("Personal Mac"))
    }
    @Test func supportLinksUseOnlyThePublicProject() {
        for link in [SupportInfo.repository, SupportInfo.setup, SupportInfo.privacy, SupportInfo.licence, SupportInfo.credits,
                     SupportInfo.releases, SupportInfo.discussions, SupportInfo.security, SupportInfo.bugReport, SupportInfo.featureRequest] {
            #expect(link.scheme == "https")
            #expect(link.host == "github.com")
            #expect(link.path.hasPrefix("/allamaprabhuani/sofa-remote"))
            #expect(link.user == nil && link.password == nil && link.fragment == nil)
        }
    }
}
